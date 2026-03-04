# Estructura de la Base de Datos (Firebase Firestore)

Este documento describe la estructura de las colecciones y documentos de Firestore inferidos a partir de los servicios y rutas del sistema backend.

## Colecciones Principales

### 1. `usuarios`
Almacena la información de los usuarios que acceden al sistema.
- `id` (Document ID)
- `nombre` (String)
- `email` (String)
- `password` (String)
- `rol` (String)
- `createdAt` (String ISO Timestamp)
- `updatedAt` (String ISO Timestamp)

### 2. `ganado`
Almacena los registros individuales del ganado.
- `id` (Document ID)
- `createdAt` (String ISO Timestamp)
- `updatedAt` (String ISO Timestamp)
- *(Campos dinámicos según el registro del animal, form, etc.)*

### 3. `inventario`
Gestión de artículos y suministros (medicamentos, alimentos, etc.).
- `id` (Document ID)
- `cantidad` (Number) - Cantidad actual disponible
- `stockMinimo` (Number) - Límite mínimo para alertas (por defecto 10)
- `createdAt` (String ISO Timestamp)
- `updatedAt` (String ISO Timestamp)
- *(Campos dinámicos adicionales como nombre, categoría, unidad)*

### 4. `tramites`
Gestión de trámites en el sistema. Soporta tres flujos que avanzan de etapa en etapa: `PRUEBAS_GANADO`, `MOVILIZACION`, `EXPORTACION`.
- `id` (Document ID)
- `numero_tramite` (String) - Folio auto-generado (e.g., TRM-2026-XYZ)
- `tipo` (String)
- `usuario_id` (String)
- `ganado_ids` (Array of Strings) - Referencias a documentos en `ganado`
- `fecha_solicitud` (String ISO Timestamp)
- `etapa_actual` (Number) - Controla la etapa del flujo del trámite
- `estado` (String) - `PENDIENTE`, `EN_PROCESO`, `COMPLETADO`, `CANCELADO`
- `observaciones` (String)
- `documentos` (Array of Objects) - Formato `{ nombre, tipo, url, fecha_subida }`
- `historial` (Array of Objects) - Registro de auditoría/cambios de etapa o estado
- `observaciones_list` (Array of Objects) - Bitácora de observaciones por paso o usuario

### 5. `sesiones` (Chatbot Asistente)
Historial y contexto de las conversaciones del asistente inteligente de IA.
- `id` / `sesion_id` (Document ID)
- `usuario_id` (String)
- `fecha_inicio` (String ISO Timestamp / ServerTimestamp)
- `mensajes` (Array of Objects) - Arreglo de mensajes pasados a OpenAI para el contexto (`role`, `content`, `tool_calls`).

### 6. `feedback_chatbot`
Retroalimentación del usuario respecto a respuestas de la IA.
- `id` (Document ID)
- `fecha` (String ISO Timestamp)
- *(Datos dinámicos de feedback enviados por el cliente)*
