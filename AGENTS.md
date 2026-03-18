# Agro Control Pro — Instrucciones para Agentes de IA

> Lee este archivo completo antes de hacer cualquier modificación al proyecto.

## Identidad del Proyecto

**Agro Control Pro** es un monorepo de gestión agropecuaria con cuatro módulos independientes:

| Módulo | Ruta | Stack | Puerto |
|---|---|---|---|
| Backend (API) | `backend/` | Node.js · Express · CommonJS | `3000` |
| Mobile | `mobile/` | Flutter / Dart (SDK ≥ 3.9.2) | N/A |
| IAService | `IAService/` | Python · FastAPI · Faster-Whisper | `8000` |
| Identification | `identification/` | Node.js · Express | `3000` |

## Arquitectura de Servicios

```
Mobile (Flutter) ──REST / WebSocket──▶ Backend (Express)
                                          │
                           ┌──────────────┼───────────────┐
                           ▼              ▼               ▼
                     Firebase        Azure OpenAI    Groq / IAService
                  (Firestore +       (GPT-3.5         (Speech-to-
                    Storage)          Turbo)             Text)
                                                          │
                                               Identification
                                              (Google Wallet)
```

- **Mobile → Backend**: REST + WebSocket (streaming del chatbot).
- **Backend → Firebase**: CRUD Firestore + carga/descarga Firebase Storage.
- **Backend → Azure OpenAI**: Chatbot con tool-calling y streaming.
- **Backend → Groq / IAService**: Transcripción de audio (doble vía).
- **Identification**: Microservicio independiente para credenciales Google Wallet.

## Estructura del Monorepo

```
/
├── AGENTS.md                       # ← Este archivo (reglas globales)
├── README.md
├── ESTRUCTURA_BD.md                # Esquema detallado de Firestore
├── opencode.json                   # Config de OpenCode
│
├── backend/                        # API Node.js
│   ├── AGENTS.md                   # Reglas específicas del backend
│   ├── app.js                      # Punto de entrada Express
│   ├── bin/www                     # Arranque HTTP + WebSocket
│   ├── config/
│   │   ├── firebaseConfig.js       # Firebase Admin SDK (CommonJS)
│   │   └── azureConfig.js          # Azure OpenAI (⚠️ ESM: import/export)
│   ├── routes/                     # Controladores HTTP
│   │   ├── ganado.js, usuarios.js, inventario.js
│   │   ├── tramites.js, chatbot.js, upload.js
│   │   └── users.js (legacy)
│   ├── services/                   # Lógica de negocio
│   │   ├── openAIService.js        # ⚠️ Archivo crítico (~15KB) — Agente IA
│   │   ├── chatbotService.js       # Sesiones de chat en Firestore
│   │   ├── ganadoService.js, inventarioService.js, usuariosService.js
│   │   ├── tramitesService.js      # Flujos de trámites multi-etapa
│   │   ├── firebaseStorageService.js
│   │   ├── speechService.js        # STT vía Groq API
│   │   └── transcribeService.js    # STT vía IAService local
│   ├── ws/stream.js                # WebSocket streaming handler
│   └── uploads/                    # Temp files (multer)
│
├── mobile/                         # App Flutter
│   ├── AGENTS.md                   # Reglas específicas de mobile
│   ├── pubspec.yaml
│   └── lib/
│       ├── main.dart               # Punto de entrada
│       ├── firebase_options.dart
│       └── ui/
│           ├── vistas/             # Pantallas por módulo
│           │   ├── dashboard/dashboard_inicio.dart
│           │   ├── ganado/manejo_ganado.dart, compra_grupal.dart, salida_venta.dart
│           │   ├── inventario/stock_alimentos.dart, comprar_producto.dart
│           │   ├── mapa/mapa_ganado.dart
│           │   └── Docs/Docs.dart
│           └── widgets/
│               └── agrobot_chat.dart  # Widget del chatbot (voz + texto)
│
├── IAService/                      # Microservicio Python
│   ├── AGENTS.md                   # Reglas específicas del IAService
│   ├── main.py                     # FastAPI — POST /trans
│   └── models_whisper/             # Modelos Whisper descargados
│
└── identification/                 # Google Wallet
    ├── AGENTS.md                   # Reglas específicas
    ├── index.js                    # Express app con UI inline
    └── services/googleWallet.js    # Google Wallet API
```

## Reglas Globales (aplican a TODO el proyecto)

### Antes de cualquier cambio

1. **Identifica el módulo correcto**: ¿El cambio va en `backend/`, `mobile/`, `IAService/` o `identification/`? Lee el `AGENTS.md` del módulo correspondiente.
2. **Si involucra datos de Firestore**: Lee `ESTRUCTURA_BD.md` antes de escribir código.
3. **NUNCA modifiques** `firebase-service-account.json` ni archivos `.env` con credenciales reales.
4. **NUNCA expongas** secretos, API keys o credenciales en respuestas, logs o código nuevo.

### Al crear archivos nuevos

| Tipo | Ubicación | Convención de nombre |
|---|---|---|
| Ruta backend | `backend/routes/` | `camelCase.js` — registrar en `app.js` |
| Servicio backend | `backend/services/` | `[recurso]Service.js` |
| Pantalla mobile | `mobile/lib/ui/vistas/[modulo]/` | `snake_case.dart` |
| Widget mobile | `mobile/lib/ui/widgets/` | `snake_case.dart` |
| Endpoint IA | `IAService/main.py` | Agregar al archivo existente |

### Formato de respuesta API (Backend)

Todas las respuestas HTTP del backend **deben** seguir este formato:

```json
{ "success": true, "data": { ... } }
{ "success": false, "message": "Descripción del error" }
```

### Comentarios

- Explicar el **por qué**, no el **qué**.
- JSDoc/Docstrings para funciones públicas de services.
- `// TODO:` para mejoras pendientes.
- El proyecto mezcla español e inglés — mantener coherencia con el archivo que se edite.

## Verificación de Cambios

```bash
# Backend: verifica que arranca sin errores
cd backend && npm start

# Mobile: verifica análisis estático
cd mobile && flutter analyze

# IAService: verifica que arranca
cd IAService && python main.py
```

## Documentación Externa

Cuando el agente necesite información detallada sobre la base de datos, debe leer:
- `ESTRUCTURA_BD.md` — Esquema completo de las colecciones Firestore.
