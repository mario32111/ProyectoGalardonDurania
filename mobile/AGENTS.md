# Mobile — Instrucciones para Agentes

> Reglas específicas del módulo `mobile/`. Aplican solo cuando trabajes en este directorio.

## Stack y Configuración

- **Framework**: Flutter (Dart SDK ≥ 3.9.2)
- **Plataformas**: Android, iOS, Windows
- **State Management**: `StatefulWidget` nativo (no se usa Provider, Riverpod, ni Bloc)
- **Navegación**: Navegación imperativa con `Navigator.push/pop`
- **HTTP**: Paquete `http` para REST + WebSocket nativo de Dart para streaming
- **Firebase**: `firebase_core` + `cloud_firestore`
- **Mapas**: `flutter_map` + `latlong2` (OpenStreetMap, sin Google Maps)

## Inicio Rápido

```bash
flutter pub get       # Instalar dependencias
flutter run           # Ejecutar en dispositivo/emulador
flutter analyze       # Análisis estático (verificar antes de commits)
```

## Estructura de Archivos

```
lib/
├── main.dart                   # Punto de entrada, inicialización Firebase, tema global
├── firebase_options.dart       # Configuración auto-generada de Firebase
└── ui/
    ├── vistas/                 # Pantallas organizadas por módulo funcional
    │   ├── dashboard/
    │   │   └── dashboard_inicio.dart     # Pantalla principal con resumen
    │   ├── ganado/
    │   │   ├── manejo_ganado.dart        # Listado y gestión de ganado
    │   │   ├── compra_grupal.dart        # Registro de compras grupales
    │   │   └── salida_venta.dart         # Registro de salidas/ventas
    │   ├── inventario/
    │   │   ├── stock_alimentos.dart      # Control de inventario
    │   │   └── comprar_producto.dart     # Registro de compras
    │   ├── mapa/
    │   │   └── mapa_ganado.dart          # Mapa interactivo con ubicaciones
    │   └── Docs/
    │       └── Docs.dart                 # Gestión de documentos
    └── widgets/                # Componentes reutilizables
        └── agrobot_chat.dart   # Widget del chatbot (texto + voz, ~22KB)
```

## Convenciones de Nomenclatura

| Elemento | Formato | Ejemplo |
|---|---|---|
| Archivos | `snake_case.dart` | `dashboard_inicio.dart` |
| Clases | `PascalCase` | `DashboardInicio`, `AgrobotChat` |
| Variables y funciones | `camelCase` | `getUserData`, `isLoading` |
| Constantes | `lowerCamelCase` con `const`/`final` | `const defaultPadding = 16.0` |
| Carpetas de vistas | `snake_case` o nombre de módulo | `ganado/`, `inventario/` |

## Al Crear Archivos Nuevos

- **Nueva pantalla**: `lib/ui/vistas/[modulo]/nombre_pantalla.dart`
  - Crear carpeta del módulo si no existe.
  - Registrar la navegación (vía `Navigator.push`) desde la pantalla que la invoque.
- **Nuevo widget reutilizable**: `lib/ui/widgets/nombre_widget.dart`
- **Nuevo servicio/helper**: `lib/services/nombre_service.dart` (crear carpeta si no existe).

## Conexión con el Backend

La app se conecta al backend Express vía:

1. **REST (HTTP)**: Para CRUD de ganado, inventario, usuarios, trámites, uploads.
2. **WebSocket**: Para streaming del chatbot (respuestas token-a-token).

> La URL base del backend se configura en el código. Buscar la constante/variable que define la URL del servidor.

### Ejemplo de petición REST

```dart
final response = await http.post(
  Uri.parse('$baseUrl/ganado'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode(data),
);
final json = jsonDecode(response.body);
if (json['success']) {
  // Usar json['data']
}
```

## Widget del Chatbot (`agrobot_chat.dart`)

Es el widget más grande del proyecto (~22KB). Implementa:

- **Chat de texto**: Envía mensajes al backend y recibe respuestas via streaming.
- **Entrada de voz**: Graba audio, lo envía al backend para transcripción (Groq/Whisper), y muestra la respuesta.
- **Sesiones**: Mantiene un `session_id` único por conversación.
- **UI rica**: Burbujas de chat, indicadores de escritura, botón de micrófono.

> ⚠️ Al modificar este widget, tener cuidado con el manejo del WebSocket y la gestión del ciclo de vida (dispose de streams y controladores).

## Estilo de Código

- Seguir las [convenciones oficiales de Dart](https://dart.dev/effective-dart/style).
- **Sangría**: 2 espacios (estándar de Dart).
- **Trailing commas**: Usar siempre en argumentos de widgets para mejor formateo automático.
- **`const` constructors**: Usar siempre que sea posible para optimización.
- **Comentarios**: En español, coherente con el resto del proyecto.

## Dependencias (`pubspec.yaml`)

| Paquete | Versión | Uso |
|---|---|---|
| `flutter_map` | ^6.1.0 | Mapas interactivos (OpenStreetMap) |
| `latlong2` | ^0.9.0 | Coordenadas geográficas |
| `geolocator` | ^13.0.0 | GPS / ubicación del dispositivo |
| `firebase_core` | ^3.1.0 | Núcleo de Firebase |
| `cloud_firestore` | ^5.0.0 | Base de datos Firestore |
| `http` | ^1.2.0 | Peticiones HTTP |
| `uuid` | ^4.5.0 | Generación de session IDs |
| `image_picker` | ^1.2.1 | Captura de fotos desde cámara/galería |

## Temas y Diseño

- El tema global se define en `main.dart`.
- Colores principales del proyecto: Verde oscuro (#0f4a3e) como color primario.
- Usar `Theme.of(context)` para acceder a colores y estilos consistentes.
- Diseño Material 3 habilitado.
