# =============================================
# Backend — Dockerfile (Desarrollo)
# Node.js 20 + Express API
# =============================================
FROM node:20-alpine

WORKDIR /app

# Copiar package.json y lock para aprovechar caché de capas
COPY package.json package-lock.json ./

# Instalar dependencias
RUN npm ci

# Copiar el resto del código fuente
COPY . .

# Crear carpeta de uploads temporal
RUN mkdir -p uploads

# Puerto por defecto del backend
EXPOSE 3000

# Arrancar el servidor
CMD ["npm", "start"]
