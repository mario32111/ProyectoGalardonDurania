# =============================================
# ApiDetection — Dockerfile (Desarrollo)
# Node.js 20 + Python 3.11 + YOLO (ultralytics)
# =============================================

# Usar imagen base de Python ya que YOLO depende de PyTorch
FROM python:3.11-slim

# Instalar Node.js 20 dentro de la imagen de Python
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libgl1 \
    libglib2.0-0 \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# --- Paso 1: Instalar dependencias de Python ---
# ultralytics incluye PyTorch, OpenCV, etc.
RUN pip install --no-cache-dir ultralytics

# --- Paso 2: Instalar dependencias de Node.js ---
COPY package.json package-lock.json ./
RUN npm ci

# --- Paso 3: Copiar código fuente ---
COPY . .

# Crear carpeta de uploads temporal
RUN mkdir -p uploads

# Puerto por defecto de la API de detección
EXPOSE 3002

# Arrancar el servidor Node.js
CMD ["npm", "start"]
