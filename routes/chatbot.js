var express = require('express');
var router = express.Router();
var wss = require('../ws/stream');
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

    // Llamamos al servicio pasando el adaptador
    await openAIService.completion(session_id, message, wss);

  } catch (error) {
    next(error);
  }
});

// GET /chatbot/historial/:usuario_id - Obtener historial de conversaciones
router.get('/historial/:usuario_id', async function (req, res, next) {
  try {
    const { db } = require('../config/firebaseConfig');
    const { usuario_id } = req.params;
    const { limite = 50 } = req.query;

    const snapshot = await db.collection('sesiones')
      .where('usuario_id', '==', usuario_id)
      .orderBy('fecha_inicio', 'desc')
      .limit(Number(limite))
      .get();

    const conversaciones = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

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
    const { db } = require('../config/firebaseConfig');
    const { sesion_id } = req.params;

    const doc = await db.collection('sesiones').doc(sesion_id).get();

    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'Sesión no encontrada' });
    }

    res.status(200).json({
      success: true,
      message: 'Mensajes de la sesión',
      data: {
        sesion_id: doc.id,
        ...doc.data()
      }
    });
  } catch (error) {
    next(error);
  }
});

// POST /chatbot/sesion/nueva - Iniciar una nueva sesión de chat
router.post('/sesion/nueva', async function (req, res, next) {
  try {
    const { db } = require('../config/firebaseConfig');
    const { usuario_id } = req.body;

    const nuevaSesion = {
      usuario_id,
      fecha_inicio: new Date().toISOString(),
      mensajes: []
    };

    const docRef = await db.collection('sesiones').add(nuevaSesion);

    res.status(201).json({
      success: true,
      message: 'Nueva sesión creada',
      data: {
        sesion_id: docRef.id,
        ...nuevaSesion
      }
    });
  } catch (error) {
    next(error);
  }
});

// DELETE /chatbot/sesion/:sesion_id - Finalizar/eliminar una sesión
router.delete('/sesion/:sesion_id', async function (req, res, next) {
  try {
    const { db } = require('../config/firebaseConfig');
    const { sesion_id } = req.params;

    await db.collection('sesiones').doc(sesion_id).delete();

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
    const { db } = require('../config/firebaseConfig');
    const { session_id, mensaje_id, calificacion, comentario } = req.body;

    const feedbackData = {
      session_id,
      mensaje_id,
      calificacion,
      comentario,
      fecha: new Date().toISOString()
    };

    await db.collection('feedback_chatbot').add(feedbackData);

    res.status(200).json({
      success: true,
      message: 'Feedback recibido',
      data: feedbackData
    });
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
