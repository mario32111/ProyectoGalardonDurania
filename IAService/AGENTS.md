# IAService — Instrucciones para Agentes

> Reglas específicas del módulo `IAService/`. Aplican solo cuando trabajes en este directorio.

## Stack y Configuración

- **Lenguaje**: Python 3.9+
- **Framework**: FastAPI + Uvicorn
- **Modelo**: Faster-Whisper (modelo `base`, cuantización `int8`)
- **Audio**: pydub para conversión de formatos
- **GPU**: Detección automática CUDA/CPU vía PyTorch

## Inicio Rápido

```bash
# Crear entorno virtual (recomendado)
python -m venv venv

# Activar entorno (Windows)
.\venv\Scripts\activate

# Instalar dependencias
pip install fastapi uvicorn faster-whisper pydub torch

# Iniciar servidor (puerto 8000)
python main.py
```

> El modelo Whisper se descarga automáticamente al directorio `models_whisper/` en el primer inicio.

## Estructura

```
IAService/
├── main.py              # App FastAPI completa (endpoints + lógica)
├── models_whisper/      # Modelos Whisper descargados (auto-generado)
└── .gitignore
```

## Endpoint Único

| Método | Ruta | Descripción |
|---|---|---|
| `POST` | `/trans` | Transcribe un archivo de audio a texto |

### Request

- **Content-Type**: `multipart/form-data`
- **Parámetros**:
  - `file` (required): Archivo de audio (cualquier formato soportado por pydub/ffmpeg)
  - `language` (optional, query): Código de idioma (ej: `es`, `en`)

### Response

```json
{ "texto": "Texto transcrito del audio" }
```

### Flujo interno

1. Recibe archivo de audio vía multipart.
2. Guarda temporalmente con nombre único (`temp_{uuid}.ext`).
3. Convierte a WAV 16kHz mono vía `pydub`.
4. Transcribe con Faster-Whisper (`beam_size=1` para velocidad).
5. Limpia archivos temporales.
6. Retorna texto transcrito.

## Estilo de Código

- **PEP 8** estricto.
- **Sangría**: 4 espacios.
- **Funciones**: `snake_case` (ej: `convert_to_wav_16k`).
- **Constantes**: `SCREAMING_SNAKE_CASE` (ej: `WHISPER_MODEL_SIZE`).
- **Docstrings**: Triple comillas dobles (`"""..."""`).
- **Type hints**: Usar siempre en parámetros de funciones y endpoints.

## Al Agregar Nuevos Endpoints

Agregar directamente en `main.py`. Seguir el patrón existente:

```python
@app.post("/nuevo_endpoint")
def mi_endpoint(param: str = Query(...)):
    """Descripción del endpoint."""
    try:
        # lógica
        return {"resultado": valor}
    except Exception as e:
        return {"error": str(e)}
```

## Notas Importantes

- **FFmpeg requerido**: `pydub` necesita FFmpeg instalado en el sistema para la conversión de audio.
- **GPU opcional**: Si hay CUDA disponible, Whisper usa GPU automáticamente. Si no, usa CPU.
- **Archivos temporales**: Se limpian automáticamente en el bloque `finally` de cada request.
- Este servicio es invocado por el backend vía `services/transcribeService.js`.
