var express = require('express');
var router = express.Router();
const chatbotService = require('../services/chatbotService');
const EventEmitter = require('events');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const speechService = require('../services/speechService');

// Configurar multer para almacenar archivos de audio temporalmente
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, '..', 'uploads');
    if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    cb(null, `audio_${Date.now()}${path.extname(file.originalname)}`);
  }
});
const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB máximo
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['audio/wav', 'audio/wave', 'audio/x-wav', 'audio/mpeg', 'audio/mp3', 'audio/ogg', 'audio/webm', 'audio/mp4'];
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error(`Tipo de audio no soportado: ${file.mimetype}. Usa WAV, MP3, OGG o WebM.`));
    }
  }
});
/**
 * Rutas para Chatbot
 * Gestión de interacciones con el chatbot de la plataforma ganadera
 */

// POST /chatbot/message - Enviar un mensaje al chatbot
router.post('/message', async function (req, res, next) {
  try {
    const { message, session_id } = req.body;
    console.log('Mensaje recibido:', message);
    console.log('Sesión ID:', session_id);

    const openAIService = require('../services/openAIService');

    // Crear un adaptador HTTP que emula la interfaz de ws para capturar la respuesta
    const httpAdapter = new EventEmitter();
    let fullResponse = '';

    // emitEvent() en openAIService usa ws.emit() si no tiene ws.send()
    // Capturamos los eventos emitidos
    httpAdapter.on('ai_chunk', (data) => {
      fullResponse += data.chunk;
    });

    // Llamamos al servicio pasando el adaptador
    await openAIService.completion(session_id, message, httpAdapter);

    // Enviamos la respuesta completa al cliente HTTP
    res.status(200).json({
      success: true,
      message: 'Respuesta del chatbot',
      data: {
        response: fullResponse,
        session_id: session_id
      }
    });

  } catch (error) {
    next(error);
  }
});

// GET /chatbot/historial/:usuario_id - Obtener historial de conversaciones
router.get('/historial/:usuario_id', async function (req, res, next) {
  try {
    const { usuario_id } = req.params;
    const { limite = 50 } = req.query;

    const conversaciones = await chatbotService.getHistorial(usuario_id, limite);

    res.status(200).json({
      success: true,
      message: 'Historial de conversaciones',
      data: {
        conversaciones: conversaciones,
        total: conversaciones.length
      }
    });
  } catch (error) {
    next(error);
  }
});

// GET /chatbot/sesion/:sesion_id - Obtener mensajes de una sesión específica
router.get('/sesion/:sesion_id', async function (req, res, next) {
  try {
    const { sesion_id } = req.params;
    const data = await chatbotService.getSesion(sesion_id);

    if (!data) return res.status(404).json({ success: false, message: 'Sesión no encontrada' });

    res.status(200).json({ success: true, message: 'Mensajes de la sesión', data });
  } catch (error) {
    next(error);
  }
});

// POST /chatbot/sesion/nueva - Iniciar una nueva sesión de chat
router.post('/sesion/nueva', async function (req, res, next) {
  try {
    const { usuario_id } = req.body;
    const data = await chatbotService.createSesion(usuario_id);

    res.status(201).json({ success: true, message: 'Nueva sesión creada', data });
  } catch (error) {
    next(error);
  }
});

// DELETE /chatbot/sesion/:sesion_id - Finalizar/eliminar una sesión
router.delete('/sesion/:sesion_id', async function (req, res, next) {
  try {
    const { sesion_id } = req.params;
    await chatbotService.deleteSesion(sesion_id);

    res.status(200).json({
      success: true,
      message: `Sesión ${sesion_id} finalizada y eliminada`
    });
  } catch (error) {
    next(error);
  }
});

// POST /chatbot/feedback - Enviar feedback sobre una respuesta
router.post('/feedback', async function (req, res, next) {
  try {
    const data = await chatbotService.saveFeedback(req.body);
    res.status(200).json({ success: true, message: 'Feedback recibido', data });
  } catch (error) {
    next(error);
  }
});

// GET /chatbot/sugerencias - Obtener sugerencias de preguntas frecuentes
router.get('/sugerencias', async function (req, res, next) {
  try {
    // Si quieres que vengan de la DB:
    // const snapshot = await db.collection('sugerencias_chatbot').get();
    // const sugerencias = snapshot.docs.map(d => d.data().texto);

    // Por ahora estático pero listo para Firebase si se descomenta
    res.status(200).json({
      success: true,
      message: 'Sugerencias de preguntas',
      data: {
        sugerencias: [
          '¿Cómo registro un nuevo animal?',
          '¿Cómo consulto el inventario?',
          '¿Cómo actualizo el estado de salud del ganado?',
          '¿Cómo genero reportes?'
        ]
      }
    });
  } catch (error) {
    next(error);
  }
});

// ============================
// RUTAS DE AUDIO (Speech-to-Text)
// ============================

// POST /chatbot/audio - Transcribir un archivo de audio a texto
router.post('/audio', upload.single('audio'), async function (req, res, next) {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No se recibió ningún archivo de audio. Envía un archivo con el campo "audio".'
      });
    }

    console.log('🎙️ Audio recibido:', req.file.originalname, `(${(req.file.size / 1024).toFixed(1)}KB)`);

    const result = await speechService.transcribeFile(req.file.path);

    // Limpiar archivo temporal
    fs.unlink(req.file.path, (err) => {
      if (err) console.error('Error eliminando archivo temporal:', err);
    });

    res.status(200).json({
      success: true,
      message: 'Audio transcrito exitosamente',
      data: {
        text: result.text,
        segments: result.segments
      }
    });
  } catch (error) {
    // Limpiar archivo si hubo error
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlink(req.file.path, () => { });
    }
    next(error);
  }
});

// POST /chatbot/audio-chat - Transcribir audio y enviarlo al chatbot en un solo paso
router.post('/audio-chat', upload.single('audio'), async function (req, res, next) {
  try {
    if (!req.file) {
      return res.status(400).json({
        success: false,
        message: 'No se recibió ningún archivo de audio. Envía un archivo con el campo "audio".'
      });
    }

    const { session_id } = req.body;
    console.log('🎙️ Audio-Chat recibido:', req.file.originalname, `(${(req.file.size / 1024).toFixed(1)}KB)`);

    // Paso 1: Transcribir audio
    const transcription = await speechService.transcribeFile(req.file.path);

    // Limpiar archivo temporal
    fs.unlink(req.file.path, (err) => {
      if (err) console.error('Error eliminando archivo temporal:', err);
    });

    if (!transcription.text) {
      return res.status(200).json({
        success: false,
        message: 'No se detectó habla en el audio',
        data: { transcription: '', response: '' }
      });
    }

    console.log('📝 Texto transcrito:', transcription.text);

    // Paso 2: Enviar texto transcrito al chatbot
    const openAIService = require('../services/openAIService');
    const httpAdapter = new EventEmitter();
    let fullResponse = '';

    httpAdapter.on('ai_chunk', (data) => {
      fullResponse += data.chunk;
    });

    await openAIService.completion(session_id, transcription.text, httpAdapter);

    res.status(200).json({
      success: true,
      message: 'Audio procesado y respuesta generada',
      data: {
        transcription: transcription.text,
        response: fullResponse,
        session_id: session_id
      }
    });
  } catch (error) {
    if (req.file && fs.existsSync(req.file.path)) {
      fs.unlink(req.file.path, () => { });
    }
    next(error);
  }
});

module.exports = router;
