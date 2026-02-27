var express = require('express');
var router = express.Router();
const chatbotService = require('../services/chatbotService');
const EventEmitter = require('events');
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

module.exports = router;
