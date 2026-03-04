# Proyecto Galardón - Agro Control Pro

Bienvenido al repositorio de **Agro Control Pro**, una solución integral para la gestión agropecuaria inteligente. Este proyecto combina una aplicación móvil moderna, un backend robusto y servicios de Inteligencia Artificial para optimizar el control de ganado, inventarios y trámites.

## 🚀 Estructura del Proyecto

El sistema está dividido en tres componentes principales:

1.  **Mobile (`/mobile`)**: Aplicación desarrollada en **Flutter** para Android/iOS/Windows. Actúa como la interfaz principal para el usuario.
2.  **Backend (`/backend`)**: Servidor **Node.js con Express** que gestiona la lógica de negocio, bases de datos (Firebase) y comunicación entre servicios.
3.  **Servicio de IA (`/IAService`)**: Microservicio en **Python (FastAPI)** encargado del procesamiento de audio y transcripción utilizando modelos como **Whisper**.

---

## 🛠️ Tecnologías Utilizadas

### Mobile
-   **Framework**: Flutter (Dart)
-   **Plataformas**: Android, iOS, Windows
-   **Características**: Diseño responsivo, gestión de estado, integración con APIs REST.

### Backend
-   **Runtime**: Node.js
-   **Framework**: Express.js
-   **Base de Datos/Auth**: Firebase Admin SDK
-   **Integraciones**: OpenAI API, WebSockets (ws)
-   **Módulos Principales**:
    -   Gestión de Ganado
    -   Usuarios
    -   Inventario
    -   Chatbot (Asistente Virtual)
    -   Trámites

### AI Service
-   **Framework**: FastAPI (Python)
-   **Modelos**: Faster Whisper (Int8 quantización)
-   **Funcionalidades**: Transcripción de audio a texto (Speech-to-Text) de alta eficiencia.

---

## 📋 Prerrequisitos

Asegúrate de tener instalado lo siguiente:
-   **Node.js** (v18 o superior)
-   **Python** (v3.9 o superior)
-   **Flutter SDK**
-   **Git**

---

## ⚙️ Instalación y Ejecución

### 1. Configuración del Backend (Node.js)

```bash
cd backend
npm install
# Iniciar servidor
npm start
```
*El servidor corre por defecto en el puerto 3000 (o el definido en `bin/www`).*

### 2. Configuración del Servicio de IA (Python)

```bash
cd IAService
# Crear entorno virtual (opcional pero recomendado)
python -m venv venv
# Activar entorno (Windows)
.\venv\Scripts\activate
# Instalar dependencias
pip install -r requirements.txt
# Iniciar servidor
python main.py
```
*El servicio de IA se ejecutará en `http://0.0.0.0:8000` y descargará automáticamente el modelo Whisper base si no existe.*

### 3. Ejecución de la App Móvil (Flutter)

```bash
cd mobile
flutter pub get
# Ejecutar en el dispositivo seleccionado
flutter run
```

---

## 🗄️ Estructura de la Base de Datos (Firebase)

A continuación se presenta un resumen de las colecciones y atributos clave inferidos de los servicios (para más detalle, revisar `ESTRUCTURA_BD.md`):

- **`usuarios`**: Datos de acceso y roles (`nombre`, `email`, `rol`).
- **`ganado`**: Registros individuales e historiales de los animales.
- **`inventario`**: Control de stock de recursos, suministros y medicamentos (`cantidad`, `stockMinimo`).
- **`tramites`**: Control de flujos (`tipo`, `etapa_actual`, `estado`), historial y documentos adjuntos.
- **`sesiones`** y **`feedback_chatbot`**: Historial de chats del asistente de IA (`mensajes`, context).

---

## 🌟 Funcionalidades Clave

-   **Gestión de Ganado**: Registro y seguimiento detallado de animales.
-   **Control de Inventario**: Administración de recursos y suministros.
-   **Asistente Inteligente (Chatbot)**: Interacción natural mediante voz y texto, potenciada por Whisper (transcripción) y OpenAI.
-   **Gestión de Trámites**: Organización de procesos administrativos.

## 🤝 Contribución

Si deseas contribuir, por favor crea un *fork* del repositorio y envía un *pull request* con tus mejoras.

---
**Desarrollado con ❤️ para innovar en el campo.**
