# API Routes - Plataforma Ganadera

## Estructura de Rutas

### 1. Ganado (`/ganado`)
Gestión de animales de la plataforma

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/ganado` | Obtener todos los registros de ganado |
| GET | `/ganado/:id` | Obtener un registro específico |
| POST | `/ganado` | Crear nuevo registro de ganado |
| PUT | `/ganado/:id` | Actualizar registro completo |
| DELETE | `/ganado/:id` | Eliminar registro |

**Ejemplo de payload para crear ganado:**
```json
{
  "nombre": "Vaca 001",
  "raza": "Holstein",
  "edad": 3,
  "peso": 450,
  "estado_salud": "Saludable",
  "fecha_ingreso": "2025-01-15"
}
```

---

### 2. Usuarios (`/usuarios`)
Gestión de usuarios de la plataforma

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/usuarios` | Obtener todos los usuarios |
| GET | `/usuarios/:id` | Obtener usuario específico |
| POST | `/usuarios` | Crear nuevo usuario |
| PUT | `/usuarios/:id` | Actualizar usuario |
| DELETE | `/usuarios/:id` | Eliminar usuario |
| POST | `/usuarios/login` | Autenticación de usuario |

**Ejemplo de payload para crear usuario:**
```json
{
  "nombre": "Juan Pérez",
  "email": "juan@example.com",
  "password": "password123",
  "rol": "administrador",
  "telefono": "+34 123456789"
}
```

---

### 3. Inventario (`/inventario`)
Gestión de inventario (alimentos, medicamentos, equipos)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/inventario` | Obtener todos los items |
| GET | `/inventario/:id` | Obtener item específico |
| POST | `/inventario` | Agregar nuevo item |
| PUT | `/inventario/:id` | Actualizar item |
| DELETE | `/inventario/:id` | Eliminar item |
| PATCH | `/inventario/:id/stock` | Actualizar solo stock |
| GET | `/inventario/alertas/stock-bajo` | Items con stock bajo |

**Ejemplo de payload para crear item:**
```json
{
  "nombre": "Alimento Balanceado",
  "categoria": "alimento",
  "cantidad": 100,
  "unidad_medida": "kg",
  "precio_unitario": 25.50,
  "fecha_vencimiento": "2025-12-31",
  "proveedor": "Proveedor SA"
}
```

---

### 4. Chatbot (`/chatbot`)
Interacción con el chatbot de la plataforma

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| POST | `/chatbot/mensaje` | Enviar mensaje al chatbot |
| GET | `/chatbot/historial/:usuario_id` | Obtener historial de conversaciones |
| GET | `/chatbot/sesion/:sesion_id` | Obtener mensajes de una sesión |
| POST | `/chatbot/sesion/nueva` | Iniciar nueva sesión |
| DELETE | `/chatbot/sesion/:sesion_id` | Finalizar sesión |
| POST | `/chatbot/feedback` | Enviar feedback |
| GET | `/chatbot/sugerencias` | Obtener preguntas sugeridas |

**Ejemplo de payload para enviar mensaje:**
```json
{
  "mensaje": "¿Cómo registro un nuevo animal?",
  "usuario_id": "123",
  "sesion_id": "sesion_abc123"
}
```

---

### 5. Trámites (`/tramites`)
Sistema de seguimiento de trámites ganaderos con etapas (como pedidos de MercadoLibre)

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/tramites` | Obtener todos los trámites (con filtros) |
| GET | `/tramites/tipos` | Obtener tipos de trámites y sus etapas |
| GET | `/tramites/:id` | Obtener detalles de un trámite |
| GET | `/tramites/:id/seguimiento` | Seguimiento detallado con historial completo |
| POST | `/tramites` | Crear nuevo trámite |
| PUT | `/tramites/:id/avanzar-etapa` | Avanzar a siguiente etapa |
| PUT | `/tramites/:id/actualizar-etapa` | Actualizar a etapa específica |
| PUT | `/tramites/:id/estado` | Cambiar estado del trámite |
| POST | `/tramites/:id/observaciones` | Agregar observación |
| POST | `/tramites/:id/documentos` | Agregar documento |
| GET | `/tramites/:id/documentos` | Obtener documentos del trámite |
| DELETE | `/tramites/:id` | Cancelar trámite |
| GET | `/tramites/usuario/:usuario_id` | Trámites de un usuario |
| GET | `/tramites/stats/general` | Estadísticas generales |

**Tipos de trámites disponibles:**

1. **PRUEBAS_GANADO** - Pruebas sanitarias para detectar enfermedades
   - Etapas: Solicitud Recibida → Programación de Visita → Toma de Muestras → Muestras en Laboratorio → Resultados Disponibles → Finalizado

2. **MOVILIZACION** - Trámites para movilización de ganado
   - Etapas: Solicitud Recibida → Revisión Documental → Inspección Sanitaria → Aprobación Pendiente → Guía Emitida → Finalizado

3. **EXPORTACION** - Trámites para exportación internacional
   - Etapas: Solicitud Recibida → Revisión Documental → Certificaciones Sanitarias → Inspección Aduanal → Aprobación SENASA → Documentación Lista → Finalizado

**Ejemplo de payload para crear trámite:**
```json
{
  "tipo": "PRUEBAS_GANADO",
  "usuario_id": "123",
  "ganado_ids": ["ganado_001", "ganado_002"],
  "observaciones": "Pruebas anuales de rutina",
  "documentos": []
}
```

**Respuesta con seguimiento de etapas:**
```json
{
  "success": true,
  "data": {
    "id": "tramite_001",
    "numero_tramite": "TRM-2026-001",
    "tipo": "PRUEBAS_GANADO",
    "tipo_nombre": "Pruebas de Ganado",
    "fecha_solicitud": "2026-01-26T10:00:00.000Z",
    "fecha_estimada_finalizacion": "2026-02-02T10:00:00.000Z",
    "etapa_actual": {
      "orden": 3,
      "nombre": "Toma de Muestras",
      "descripcion": "Veterinario tomando muestras del ganado",
      "fecha_inicio": "2026-01-25T10:00:00.000Z"
    },
    "total_etapas": 6,
    "progreso_porcentaje": 50,
    "estado": "EN_PROCESO",
    "historial": [
      {
        "etapa": 1,
        "nombre": "Solicitud Recibida",
        "fecha_inicio": "2026-01-20T10:00:00.000Z",
        "fecha_fin": "2026-01-20T10:30:00.000Z",
        "responsable": "Sistema"
      }
    ]
  }
}
```

**Estados posibles:**
- `PENDIENTE`: Trámite creado, esperando inicio
- `EN_PROCESO`: Trámite en ejecución
- `COMPLETADO`: Trámite finalizado exitosamente
- `CANCELADO`: Trámite cancelado

**Ejemplo de avanzar etapa:**
```json
{
  "responsable": "Dr. Carlos Ramírez",
  "observaciones": "Muestras tomadas correctamente"
}
```

---

## Respuesta Estándar

Todas las rutas devuelven un formato JSON consistente:

**Respuesta exitosa:**
```json
{
  "success": true,
  "message": "Descripción de la operación",
  "data": {}
}
```

**Respuesta de error:**
```json
{
  "success": false,
  "message": "Descripción del error",
  "error": "Detalles del error"
}
```

---

## Integración con Chatbot

Las rutas de trámites están diseñadas para ser consultadas por el chatbot en el futuro:
- El chatbot podrá consultar el estado de trámites
- Responder preguntas sobre el proceso
- Notificar cambios de etapa
- Proporcionar estimaciones de tiempo

---

## Próximos Pasos

1. **Conectar a Base de Datos**: Implementar conexión a MongoDB o MySQL
2. **Validación**: Agregar validación de datos con express-validator
3. **Autenticación**: Implementar JWT para proteger rutas
4. **Middleware**: Crear middleware para verificar permisos
5. **Notificaciones**: Sistema de notificaciones por email/SMS al cambiar etapas
6. **Integración Chatbot**: Conectar con servicio de IA (OpenAI, Dialogflow, etc.)
7. **Sistema de Archivos**: Implementar upload de documentos (multer)
8. **WebSockets**: Actualización en tiempo real del estado de trámites

---

## Iniciar el Servidor

```bash
npm start
```

El servidor estará disponible en `http://localhost:3000`

### Endpoints disponibles:
- `http://localhost:3000/ganado`
- `http://localhost:3000/usuarios`
- `http://localhost:3000/inventario`
- `http://localhost:3000/chatbot`
- `http://localhost:3000/tramites`
