import uvicorn
from fastapi import FastAPI, UploadFile, File, Query
from faster_whisper import WhisperModel
from pydub import AudioSegment
import torch
import shutil
import os
import uuid

# ==========================================
# CONFIGURACIÓN E INICIALIZACIÓN
# ==========================================

print("--- INICIANDO SERVIDOR DE IA (WHISPER) ---")
device_str = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Dispositivo detectado: {device_str}")

# --- 1. WHISPER (Transcripción) ---
WHISPER_MODEL_SIZE = "base"
print(f"\nCargando Whisper ({WHISPER_MODEL_SIZE})...")
try:
    whisper_model = WhisperModel(WHISPER_MODEL_SIZE, device=device_str, compute_type="int8", download_root="./models_whisper")
    print("✅ Whisper Listo.")
except Exception as e:
    print(f"❌ Error Whisper: {e}")
    exit(1)

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

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)