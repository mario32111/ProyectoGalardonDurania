import uvicorn
from fastapi import FastAPI, UploadFile, File, Query, HTTPException, Form
from faster_whisper import WhisperModel
from pydub import AudioSegment
from transformers import AutoModelForAudioClassification, AutoFeatureExtractor
import torch
import torch.nn.functional as F
import librosa
import numpy as np
import tempfile
import shutil
import os
import time
import uuid

# ==========================================
# CONFIGURACIÓN E INICIALIZACIÓN
# ==========================================

print("--- INICIANDO SERVIDOR DE IA (3 MODELOS INDEPENDIENTES) ---")
device_str = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Dispositivo detectado: {device_str}")

# --- 1. WHISPER (Transcripción) ---
WHISPER_MODEL_SIZE = "base"
print(f"\n[1/3] Cargando Whisper ({WHISPER_MODEL_SIZE})...")
try:
    whisper_model = WhisperModel(WHISPER_MODEL_SIZE, device=device_str, compute_type="int8", download_root="./models_whisper")
    print("✅ Whisper Listo.")
except Exception as e:
    print(f"❌ Error Whisper: {e}")
    exit(1)

# --- 2. EMOCIONES (Voz Humana) ---
print("\n[2/3] Cargando modelo de Emociones...")
EMOTION_MODEL_ID = "superb/wav2vec2-base-superb-er"  # El modelo estable

try:
    print(f"🔄 Cargando: {EMOTION_MODEL_ID}...")
    emotion_extractor = AutoFeatureExtractor.from_pretrained(EMOTION_MODEL_ID, cache_dir="./models_emotion")
    emotion_model = AutoModelForAudioClassification.from_pretrained(EMOTION_MODEL_ID, cache_dir="./models_emotion")
    emotion_model = emotion_model.to(device_str)
    id2label_emotion = emotion_model.config.id2label
    print(f"✅ Sistema de Emociones listo.")
except Exception as e:
    print(f"❌ Error fatal cargando emociones: {e}")
    exit(1)

# --- 3. SONIDO AMBIENTAL (Fondo/Peligros) ---
print("\n[3/3] Cargando modelo de Ambiente (AST)...")
ENV_MODEL_ID = "MIT/ast-finetuned-audioset-10-10-0.4593"

try:
    print(f"🔄 Cargando: {ENV_MODEL_ID}...")
    env_extractor = AutoFeatureExtractor.from_pretrained(ENV_MODEL_ID, cache_dir="./models_env")
    env_model = AutoModelForAudioClassification.from_pretrained(ENV_MODEL_ID, cache_dir="./models_env")
    env_model = env_model.to(device_str)
    id2label_env = env_model.config.id2label
    print(f"✅ Sistema Ambiental listo.")
except Exception as e:
    print(f"❌ Error fatal cargando modelo ambiental: {e}")
    exit(1)

# Lista de sonidos peligrosos para filtrar
DANGEROUS_SOUNDS = [
    "Gunshot, gunfire", "Explosion", "Cap gun", "Fusillade", "Artillery fire", 
    "Siren", "Police car (siren)", "Ambulance (siren)", "Fire engine, fire truck (siren)", 
    "Civil defense siren", "Screaming", "Crying, sobbing", "Whimper", "Glass", 
    "Breaking", "Shatter", "Smash, crash", "Aggressive"
]

# ==========================================
# FUNCIONES AUXILIARES
# ==========================================

def convert_to_wav_16k(file_path):
    """Convierte cualquier audio a WAV 16kHz Mono para las IAs"""
    try:
        audio = AudioSegment.from_file(file_path)
        wav_path = file_path.rsplit('.', 1)[0] + ".wav"
        # Exportar a WAV limpio
        audio.set_frame_rate(16000).set_channels(1).export(wav_path, format="wav")
        return wav_path
    except Exception as e:
        print(f"⚠️ Error conversión audio: {e}")
        return file_path

def predict_emotion_chunked(audio_path):
    """Lógica de ventanas para detectar emociones en audios largos"""
    TARGET_SR = 16000
    try:
        y, sr = librosa.load(audio_path, sr=TARGET_SR, mono=True)
    except: return None

    # Normalizar si es muy bajo
    if np.max(np.abs(y)) < 0.1: y = librosa.util.normalize(y)
    
    chunk_duration = 3.0
    chunk_samples = int(chunk_duration * TARGET_SR)
    
    # Crear chunks
    if len(y) < chunk_samples:
        chunks = [np.pad(y, (0, chunk_samples - len(y)), mode='constant')]
    else:
        stride = int(2.0 * TARGET_SR)
        chunks = [y[i : i + chunk_samples] for i in range(0, len(y) - chunk_samples + 1, stride)]
        if not chunks: chunks = [y]

    all_logits = []
    for chunk in chunks:
        inputs = emotion_extractor(chunk, sampling_rate=TARGET_SR, return_tensors="pt", padding=True)
        inputs = {k: v.to(device_str) for k, v in inputs.items()}
        with torch.no_grad():
            all_logits.append(emotion_model(**inputs).logits)

    if not all_logits: return None
    
    avg_logits = torch.mean(torch.stack(all_logits), dim=0)
    probs = F.softmax(avg_logits, dim=-1)
    
    scores = {id2label_emotion[i]: float(probs[0][i].item() * 100) for i in range(len(probs[0]))}
    predicted_label = id2label_emotion[torch.argmax(probs).item()]
    
    return {"dominante": predicted_label, "confianza": scores[predicted_label], "detalle": scores}

def predict_environment_ast(audio_path):
    """Detecta sonido de fondo (Sirenas, Disparos, etc.)"""
    TARGET_SR = 16000
    try:
        y, sr = librosa.load(audio_path, sr=TARGET_SR, mono=True)
    except: return None

    # El modelo AST procesa todo el clip (máx 10s usualmente, el extractor lo maneja)
    inputs = env_extractor(y, sampling_rate=TARGET_SR, return_tensors="pt", padding="max_length")
    inputs = {k: v.to(device_str) for k, v in inputs.items()}

    with torch.no_grad():
        logits = env_model(**inputs).logits

    # Sigmoid para multi-label (pueden sonar dos cosas a la vez)
    probs = torch.sigmoid(logits).cpu().detach().numpy()[0]
    
    # Top 5 sonidos
    top_5_indices = probs.argsort()[-5:][::-1]
    
    detected_sounds = []
    alerts = []
    
    for i in top_5_indices:
        label = id2label_env[i]
        confidence = float(probs[i] * 100)
        
        if confidence > 5.0: # Umbral mínimo de detección
            detected_sounds.append({"sonido": label, "probabilidad": round(confidence, 2)})
            
            # Checar si es peligroso
            if label in DANGEROUS_SOUNDS and confidence > 15.0:
                alerts.append(label)

    return {"alertas": alerts, "ambiente": detected_sounds}

# ==========================================
# API ENDPOINTS
# ==========================================

app = FastAPI()

# --- ENDPOINT 1: TRANSCRIPCIÓN ---
@app.post("/trans")
def transcribe_audio(file: UploadFile = File(...), language: str = Query(None)):
    temp_path = f"temp_{uuid.uuid4()}{os.path.splitext(file.filename)[1]}"
    wav_path = None
    try:
        with open(temp_path, "wb") as f: shutil.copyfileobj(file.file, f)
        wav_path = convert_to_wav_16k(temp_path)
        
        segments, _ = whisper_model.transcribe(wav_path, language=language, beam_size=1)
        text = " ".join([s.text for s in segments]).strip()
        return {"texto": text}
    finally:
        if os.path.exists(temp_path): os.remove(temp_path)
        if wav_path and os.path.exists(wav_path) and wav_path != temp_path: os.remove(wav_path)

# --- ENDPOINT 2: EMOCIONES (Voz Humana) ---
@app.post("/emotion")
def predict_emotion_endpoint(file: UploadFile = File(...)):
    temp_path = f"temp_{uuid.uuid4()}{os.path.splitext(file.filename)[1]}"
    wav_path = None
    try:
        with open(temp_path, "wb") as f: shutil.copyfileobj(file.file, f)
        wav_path = convert_to_wav_16k(temp_path)
        
        start = time.time()
        result = predict_emotion_chunked(wav_path)
        
        return {
            "archivo": file.filename,
            "emocion": result["dominante"],
            "confianza": f"{round(result['confianza'], 2)}%",
            "detalles": result["detalle"],
            "tiempo": round(time.time() - start, 2)
        }
    except Exception as e:
        return {"error": str(e)}
    finally:
        if os.path.exists(temp_path): os.remove(temp_path)
        if wav_path and os.path.exists(wav_path) and wav_path != temp_path: os.remove(wav_path)

# --- ENDPOINT 3: ANÁLISIS AMBIENTAL (Peligros de Fondo) ---
@app.post("/analyze")
def analyze_background_noise(file: UploadFile = File(...)):
    """Solo detecta sonido de fondo: Sirenas, disparos, tráfico, etc."""
    temp_path = f"temp_{uuid.uuid4()}{os.path.splitext(file.filename)[1]}"
    wav_path = None
    try:
        with open(temp_path, "wb") as f: shutil.copyfileobj(file.file, f)
        # Convertimos a WAV 16k para que el modelo AST funcione perfecto
        wav_path = convert_to_wav_16k(temp_path)
        
        start = time.time()
        result = predict_environment_ast(wav_path)
        
        # Determinar nivel de riesgo basado SOLO en sonido de fondo
        risk_level = "NORMAL"
        if len(result['alertas']) > 0:
            risk_level = "PELIGRO DETECTADO"

        return {
            "archivo": file.filename,
            "riesgo_ambiental": risk_level,
            "alertas_fondo": result["alertas"],
            "todos_los_sonidos": result["ambiente"],
            "tiempo": round(time.time() - start, 2)
        }
    except Exception as e:
        return {"error": str(e)}
    finally:
        if os.path.exists(temp_path): os.remove(temp_path)
        if wav_path and os.path.exists(wav_path) and wav_path != temp_path: os.remove(wav_path)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)