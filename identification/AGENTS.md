# Identification — Instrucciones para Agentes

> Reglas específicas del módulo `identification/`. Aplican solo cuando trabajes en este directorio.

## Stack y Configuración

- **Runtime**: Node.js
- **Framework**: Express.js v5
- **Integración**: Google Wallet API (Generic Passes)
- **Auth**: `google-auth-library`
- **Módulos**: CommonJS (`require` / `module.exports`)

## Inicio Rápido

```bash
npm install
node index.js          # Inicia en puerto 3000 (o PORT del .env)
```

## Variables de Entorno (`.env`)

| Variable | Descripción |
|---|---|
| `GOOGLE_ISSUER_ID` | ID del emisor de Google Wallet |
| `PORT` | Puerto del servidor (default: `3000`) |

> ⚠️ También requiere credenciales de servicio de Google configuradas.

## Estructura

```
identification/
├── index.js                  # App Express principal (rutas + UI inline)
├── package.json
├── services/
│   └── googleWallet.js       # Integración con Google Wallet API
└── .gitignore
```

## Rutas

| Método | Ruta | Descripción |
|---|---|---|
| `GET` | `/` | Página principal con menú |
| `GET` | `/create` | Formulario para crear credencial de prueba |
| `GET` | `/view` | Ver credenciales creadas en la sesión |
| `GET` | `/health` | Health check (`{ status: 'UP' }`) |
| `POST` | `/api/wallet/class` | Crea clase + objeto en Google Wallet y redirige a `/view` |

## Servicio `googleWallet.js`

Encapsula las llamadas a la API de Google Wallet:

- `createGenericClass(classId, classData)` — Crea una clase genérica de pass.
- `createGenericObject(objectId, objectData)` — Crea un objeto (credencial) vinculado a una clase.

## Características Especiales

- **UI inline**: Las vistas HTML están embebidas directamente en `index.js` (no hay archivos de plantilla separados).
- **Sin persistencia**: Las credenciales creadas se almacenan en un array en memoria (`createdCredentials[]`). Se pierden al reiniciar el servidor.
- **Independiente del backend principal**: Este microservicio NO comparte Firebase ni base de datos con el backend principal.

## Estilo de Código

- **CommonJS**: `require` / `module.exports`.
- **Sangría**: 2 espacios.
- **Comillas**: Simples (`'`).
- **HTML embebido**: Template literals para vistas inline. Mantener estilos CSS inline consistentes con el diseño existente (verde oscuro `#0f4a3e`, bordes redondeados, tipografía Inter/Segoe UI).

## Al Hacer Cambios

1. Las rutas y vistas están todas en `index.js`. Para cambios de UI, buscar los template literals de HTML.
2. Para nueva funcionalidad de Google Wallet, extender `services/googleWallet.js`.
3. Si necesitas persistencia real, considerar agregar Firebase o una base de datos (actualmente no tiene).
