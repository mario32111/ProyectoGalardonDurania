var express = require('express');
var router = express.Router();
const { db } = require('../config/firebaseConfig');

/**
 * CRUD para Usuarios
 * Gestión de usuarios de la plataforma ganadera
 */

// GET /usuarios - Obtener todos los usuarios
router.get('/', async function (req, res, next) {
  try {

    const snapshot = await db.collection('usuarios').get();
    const usuarios = snapshot.docs.map(doc => {
      const data = doc.data();
      delete data.password; // No devolver contraseñas
      return { id: doc.id, ...data };
    });

    res.status(200).json({
      success: true,
      message: 'Lista de usuarios',
      data: usuarios
    });
  } catch (error) {
    next(error);
  }
});

// GET /usuarios/:id - Obtener un usuario específico
router.get('/:id', async function (req, res, next) {
  try {

    const { id } = req.params;
    const doc = await db.collection('usuarios').doc(id).get();

    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'Usuario no encontrado' });
    }

    const data = doc.data();
    delete data.password;

    res.status(200).json({
      success: true,
      message: `Usuario con ID: ${id}`,
      data: { id: doc.id, ...data }
    });
  } catch (error) {
    next(error);
  }
});

// POST /usuarios - Crear un nuevo usuario
router.post('/', async function (req, res, next) {
  try {

    const data = req.body;

    // Check if email already exists
    const emailCheck = await db.collection('usuarios').where('email', '==', data.email).get();
    if (!emailCheck.empty) {
      return res.status(400).json({ success: false, message: 'El email ya está registrado' });
    }

    // TODO: Hash password here in a real app
    const newUser = {
      ...data,
      createdAt: new Date().toISOString()
    };

    const docRef = await db.collection('usuarios').add(newUser);

    delete newUser.password;

    res.status(201).json({
      success: true,
      message: 'Usuario creado exitosamente',
      data: { id: docRef.id, ...newUser }
    });
  } catch (error) {
    next(error);
  }
});

// PUT /usuarios/:id - Actualizar un usuario
router.put('/:id', async function (req, res, next) {
  try {

    const { id } = req.params;
    const data = req.body;

    const updateData = { ...data, updatedAt: new Date().toISOString() };

    await db.collection('usuarios').doc(id).update(updateData);
    delete updateData.password;

    res.status(200).json({
      success: true,
      message: `Usuario ${id} actualizado`,
      data: { id, ...updateData }
    });
  } catch (error) {
    next(error);
  }
});

// DELETE /usuarios/:id - Eliminar un usuario
router.delete('/:id', async function (req, res, next) {
  try {

    const { id } = req.params;

    await db.collection('usuarios').doc(id).delete();

    res.status(200).json({
      success: true,
      message: `Usuario ${id} eliminado`
    });
  } catch (error) {
    next(error);
  }
});

// POST /usuarios/login - Autenticación de usuario
router.post('/login', async function (req, res, next) {
  try {
    const { db } = require('../config/firebaseConfig');
    const { email, password } = req.body;

    // Buscar usuario por email
    const usersByType = await db.collection('usuarios').where('email', '==', email).limit(1).get();

    if (usersByType.empty) {
      return res.status(401).json({ success: false, message: 'Credenciales inválidas' });
    }

    const userDoc = usersByType.docs[0];
    const userData = userDoc.data();

    // Verificación simple (En prod usar bcrypt.compare)
    if (userData.password !== password) {
      return res.status(401).json({ success: false, message: 'Credenciales inválidas' });
    }

    // Retornamos ID del documento como "token" simplificado o usamos custom token
    // const token = await admin.auth().createCustomToken(userDoc.id);

    res.status(200).json({
      success: true,
      message: 'Login exitoso',
      token: userDoc.id, // En un sistema real, esto sería un JWT
      user: {
        id: userDoc.id,
        email: userData.email,
        nombre: userData.nombre,
        rol: userData.rol
      }
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
