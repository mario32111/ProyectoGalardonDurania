var express = require('express');
var router = express.Router();
const { db, admin } = require('../config/firebaseConfig');

/**
 * Rutas para gestión de Notificaciones y Tokens FCM
 */

// POST /notifications/register-token - Registrar un token para el usuario actual
router.post('/register-token', async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({ success: false, message: 'Token requerido' });
    }

    const userRef = db.collection('usuarios').doc(userId);
    
    // Usamos set con merge: true para crear el documento si no existe
    await userRef.set({
      fcmTokens: admin.firestore.FieldValue.arrayUnion(token),
      updatedAt: new Date().toISOString()
    }, { merge: true });

    res.status(200).json({ success: true, message: 'Token registrado exitosamente' });
  } catch (error) {
    next(error);
  }
});

// POST /notifications/unregister-token - Eliminar un token (ej. al cerrar sesión)
router.post('/unregister-token', async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const { token } = req.body;

    if (!token) {
      return res.status(400).json({ success: false, message: 'Token requerido' });
    }

    const userRef = db.collection('usuarios').doc(userId);
    await userRef.set({
      fcmTokens: admin.firestore.FieldValue.arrayRemove(token)
    }, { merge: true });

    res.status(200).json({ success: true, message: 'Token eliminado' });
  } catch (error) {
    next(error);
  }
});

// GET /notifications/history - Obtener historial de notificaciones
router.get('/history', async (req, res, next) => {
  try {
    const userId = req.user.uid;

    const snapshot = await db.collection('notificaciones')
      .where('usuario_id', '==', userId)
      .orderBy('fecha', 'desc')
      .limit(50)
      .get();

    const notificaciones = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    res.status(200).json({
      success: true,
      data: notificaciones
    });
  } catch (error) {
    next(error);
  }
});

// PUT /notifications/:id/read - Marcar como leída
router.put('/:id/read', async (req, res, next) => {
  try {
    const { id } = req.params;
    const userId = req.user.uid;

    const docRef = db.collection('notificaciones').doc(id);
    const doc = await docRef.get();

    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'Notificación no encontrada' });
    }

    if (doc.data().usuario_id !== userId) {
      return res.status(403).json({ success: false, message: 'No tienes permiso' });
    }

    await docRef.update({ leido: true });

    res.status(200).json({ success: true, message: 'Notificación marcada como leída' });
  } catch (error) {
    next(error);
  }
});

// POST /notifications/test-send - Enviar una notificación de prueba al usuario actual
router.post('/test-send', async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const { titulo, mensaje, tipo } = req.body;

    const notificationService = require('../services/notificationService');
    const result = await notificationService.sendToUser(userId, {
      titulo: titulo || 'Notificación de Prueba',
      mensaje: mensaje || 'Este es un mensaje de prueba',
      tipo: tipo || 'general' // 'critico', 'advertencia', 'info', 'general'
    });

    res.status(200).json(result);
  } catch (error) {
    next(error);
  }
});

module.exports = router;
