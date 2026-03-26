var express = require('express');
var router = express.Router();
const { db } = require('../config/firebaseConfig');
const axios = require('axios'); // <--- NUEVO: Para llamar a Google Auth API

/**
 * CRUD para Usuarios
 * Gestión de usuarios de la plataforma ganadera
 */

// GET /usuarios/me - Obtener el perfil del usuario actual (NUEVO)
router.get('/me', async function (req, res, next) {
  try {
    const userId = req.user.uid;
    const doc = await db.collection('usuarios').doc(userId).get();

    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'Perfil no encontrado en la base de datos' });
    }

    const data = doc.data();
    delete data.password;

    res.status(200).json({
      success: true,
      message: 'Tu perfil',
      data: { id: doc.id, ...data }
    });
  } catch (error) {
    next(error);
  }
});

// GET /usuarios/:id - Obtener detalles (Solo si es tu propio ID)
router.get('/:id', async function (req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.user.uid;

    if (id !== userId) {
      return res.status(403).json({ success: false, message: 'No tienes permiso para ver perfiles ajenos' });
    }

    const doc = await db.collection('usuarios').doc(id).get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Usuario no encontrado' });

    const data = doc.data();
    delete data.password;

    res.status(200).json({
      success: true,
      data: { id: doc.id, ...data }
    });
  } catch (error) {
    next(error);
  }
});

// PUT /usuarios/:id - Actualizar perfil propio
router.put('/:id', async function (req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.user.uid;

    if (id !== userId) {
      return res.status(403).json({ success: false, message: 'Solo puedes actualizar tu propio perfil' });
    }

    const data = req.body;
    const updateData = { 
      ...data, 
      updatedAt: new Date().toISOString() 
    };

    await db.collection('usuarios').doc(id).update(updateData);
    delete updateData.password;

    res.status(200).json({
      success: true,
      message: 'Perfil actualizado',
      data: { id, ...updateData }
    });
  } catch (error) {
    next(error);
  }
});

// DELETE /usuarios/:id - Eliminar perfil propio
router.delete('/:id', async function (req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.user.uid;

    if (id !== userId) {
      return res.status(403).json({ success: false, message: 'No puedes eliminar otros perfiles' });
    }

    await db.collection('usuarios').doc(id).delete();

    res.status(200).json({
      success: true,
      message: 'Cuenta eliminada exitosamente'
    });
  } catch (error) {
    next(error);
  }
});

/**
 * POST /usuarios/login (Proxy para Desarrollo)
 */
router.post('/login', async function (req, res, next) {
  try {
    const { email, password } = req.body;
    const apiKey = process.env.FIREBASE_WEB_API_KEY;

    if (!apiKey) {
      return res.status(500).json({ success: false, message: 'FIREBASE_WEB_API_KEY no definida en .env' });
    }

    const response = await axios.post(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
      { email, password, returnSecureToken: true }
    );

    res.status(200).json({
      success: true,
      token: response.data.idToken,
      uid: response.data.localId
    });

  } catch (error) {
    res.status(error.response?.status || 500).json({
      success: false,
      message: 'Autenticación fallida',
      error: error.response?.data?.error?.message || error.message
    });
  }
});

module.exports = router;
