# Backend — Instrucciones para Agentes

> Reglas específicas del módulo `backend/`. Aplican solo cuando trabajes en este directorio.

## Stack y Configuración

- **Runtime**: Node.js
- **Framework**: Express.js v4
- **Módulos**: **CommonJS** (`require` / `module.exports`) en todo el proyecto, **EXCEPTO** `config/azureConfig.js` que usa ESM (`import` / `export`).
- **Base de datos**: Firebase Firestore (vía `firebase-admin`)
- **Almacenamiento**: Firebase Storage
- **IA**: Azure OpenAI (GPT-3.5 Turbo) con tool-calling
- **STT**: Groq API (`speechService.js`) e IAService local (`transcribeService.js`)
- **WebSocket**: Paquete `ws` para streaming del chatbot
- **Uploads**: `multer` → directorio `uploads/`

## Inicio Rápido

```bash
npm install
npm start          # Ejecuta: node ./bin/www (puerto 3000)
```

## Variables de Entorno (`.env`)

| Variable | Descripción |
|---|---|
| `PORT` | Puerto del servidor (default: `3000`) |
| `AI_API_URL` | URL del IAService local (ej: `http://192.168.x.x:8000`) |
| `WS_URL` | Dominio para WebSocket (Ngrok u otro túnel) |
| `AZURE_OPENAI_ENDPOINT` | Endpoint de Azure OpenAI |
| `AZURE_OPENAI_API_KEY` | API Key de Azure OpenAI |
| `AZURE_OPENAI_API_VERSION` | Versión de la API (ej: `2024-04-01-preview`) |
| `AZURE_OPENAI_DEPLOYMENT_NAME` | Nombre del deployment (ej: `gpt-35-turbo`) |
| `AZURE_OPENAI_MODEL_NAME` | Nombre del modelo |
| `GROQ_API_KEY` | API Key de Groq para STT |
| `FIREBASE_STORAGE_BUCKET` | Bucket de Firebase Storage |

> ⚠️ **NUNCA** modifiques `.env` ni `firebase-service-account.json` con credenciales reales. No expongas secretos en código ni logs.

## Arquitectura de Capas

```
routes/  →  services/  →  config/ (Firebase, Azure)
  │              │
  │              └── Lógica de negocio + acceso a Firestore
  └── Validación de entrada + formato de respuesta HTTP
```

- **Las rutas** (`routes/`) reciben peticiones HTTP, validan entrada y formatean respuestas. NO deben contener lógica de negocio compleja.
- **Los servicios** (`services/`) contienen la lógica de negocio y acceden directamente a Firestore. NO deben devolver respuestas HTTP.
- **La configuración** (`config/`) inicializa clientes externos (Firebase, Azure OpenAI).

## Rutas Registradas en `app.js`

| Ruta HTTP | Archivo | Propósito |
|---|---|---|
| `/` | `routes/index.js` | Página principal |
| `/users` | `routes/users.js` | Legacy |
| `/ganado` | `routes/ganado.js` | CRUD ganado |
| `/usuarios` | `routes/usuarios.js` | CRUD usuarios |
| `/inventario` | `routes/inventario.js` | CRUD inventario |
| `/chatbot` | `routes/chatbot.js` | Chatbot (texto + audio) |
| `/tramites` | `routes/tramites.js` | Gestión de trámites |
| `/upload` | `routes/upload.js` | Carga de archivos |

**Al crear una ruta nueva**: Crear archivo en `routes/`, luego registrar en `app.js` con `app.use('/ruta', nuevoRouter);`.

## Servicios Principales

| Servicio | Responsabilidad | Tamaño |
|---|---|---|
| `openAIService.js` | **Agente IA**: system prompt, tool-calling, streaming | ~15KB ⚠️ |
| `chatbotService.js` | Sesiones de chat en Firestore | ~1.4KB |
| `ganadoService.js` | CRUD Firestore para ganado | ~1.2KB |
| `inventarioService.js` | CRUD Firestore para inventario + stock mínimo | ~2.2KB |
| `usuariosService.js` | CRUD Firestore para usuarios | ~2.2KB |
| `tramitesService.js` | Flujos de trámites multi-etapa | ~7.7KB |
| `firebaseStorageService.js` | Upload/download a Firebase Storage | ~4KB |
| `speechService.js` | STT vía Groq API | ~3.5KB |
| `transcribeService.js` | STT vía IAService local (Whisper) | ~2.6KB |

### ⚠️ `openAIService.js` — Archivo Crítico

Es el archivo más complejo del proyecto. Implementa un **agente conversacional** con:

1. **System prompt** extenso que define el comportamiento del chatbot como asistente ganadero.
2. **Tool-calling**: El agente invoca funciones (`tools`) para consultar ganado, inventario, trámites.
3. **Streaming**: Las respuestas se transmiten en tiempo real vía WebSocket.
4. **Contexto de sesión**: El historial se persiste en la colección `sesiones` de Firestore.

> Antes de modificarlo, entiende el flujo completo: `routes/chatbot.js` → `ws/stream.js` → `openAIService.js` → Azure OpenAI API.

## Flujo WebSocket (Chatbot)

```
Mobile (Dart) ──WebSocket──▶ ws/stream.js ──▶ openAIService.js ──▶ Azure OpenAI
                                   │
                                   ▼
                            Streaming tokens
                                   │
Mobile (Dart) ◀──WebSocket────────┘
```

## Transcripción de Audio (Doble Vía)

1. **Groq API** (`speechService.js`): Transcripción remota, preferida por velocidad.
2. **IAService local** (`transcribeService.js`): Transcripción con Faster-Whisper en Python.

La ruta `chatbot.js` decide cuál usar según disponibilidad.

## Estilo de Código

- **CommonJS** en todo el backend excepto `config/azureConfig.js` (ESM).
- **Sangría**: 2 espacios.
- **Comillas**: Simples (`'`).
- **Punto y coma**: Siempre.
- **Nombres**: `camelCase` para variables/funciones, `PascalCase` para clases.
- **Archivos de servicio**: `[recurso]Service.js` (ej: `ganadoService.js`).

### Orden de imports

```javascript
// 1. Módulos de Node.js
const path = require('path');

// 2. Dependencias de terceros
const express = require('express');

// 3. Módulos locales
const { db } = require('../config/firebaseConfig');
```

### Formato de respuesta

```javascript
// Éxito
res.status(200).json({ success: true, data: result });

// Error
res.status(500).json({ success: false, message: error.message });
```

### Manejo de errores en rutas

```javascript
router.post('/', async (req, res) => {
  try {
    const result = await service.create(req.body);
    res.status(201).json({ success: true, data: result });
  } catch (error) {
    console.error('Error en POST /recurso:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});
```

## Dependencias (`package.json`)

| Paquete | Versión | Uso |
|---|---|---|
| `express` | ^4.22.1 | Framework HTTP |
| `firebase-admin` | ^13.6.0 | Firestore + Storage |
| `openai` | ^6.16.0 | Cliente Azure OpenAI |
| `ws` | ^8.18.0 | WebSocket server |
| `multer` | ^2.0.2 | Upload de archivos |
| `cors` | ^2.8.6 | Cross-origin requests |
| `dotenv` | ^17.2.3 | Variables de entorno |
| `cookie-parser` | ~1.4.4 | Cookies |
| `morgan` | ^1.10.1 | Logging HTTP |

## Base de Datos

Lee `ESTRUCTURA_BD.md` en la raíz del monorepo para el esquema completo de Firestore.

Colecciones principales: `usuarios`, `ganado`, `inventario`, `tramites`, `sesiones`, `feedback_chatbot`.
