var express = require('express');
var router = express.Router();
const { db } = require('../config/firebaseConfig');

/**
 * CRUD para Ganado
 * Gestión de animales de la plataforma ganadera
 */

// GET /ganado - Obtener solo el ganado del usuario autenticado
router.get('/', async function (req, res, next) {
  try {
    const userId = req.user.uid; // Extraído del token por verifyToken

    const snapshot = await db.collection('ganado')
      .where('usuario_id', '==', userId)
      .get();
      
    const ganado = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    res.status(200).json({
      success: true,
      message: 'Lista de ganado del usuario',
      data: ganado
    });
  } catch (error) {
    next(error);
  }
});

// GET /ganado/:id - Obtener un registro específico (verificando propiedad)
router.get('/:id', async function (req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.user.uid;
    const doc = await db.collection('ganado').doc(id).get();

    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'Ganado no encontrado' });
    }

    const data = doc.data();
    if (data.usuario_id !== userId) {
      return res.status(403).json({ success: false, message: 'No tienes permiso para ver este registro' });
    }

    res.status(200).json({
      success: true,
      message: `Ganado con ID: ${id}`,
      data: { id: doc.id, ...data }
    });
  } catch (error) {
    next(error);
  }
});

// POST /ganado - Crear un nuevo registro vinculado al usuario y UPP
router.post('/', async function (req, res, next) {
  try {
    const userId = req.user.uid;
    const data = req.body;

    // Estandarización de datos
    const newData = {
      ...data,
      usuario_id: userId,
      upp: data.upp || 'N/A', // Aseguramos que el campo UPP exista
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };

    const docRef = await db.collection('ganado').add(newData);

    res.status(201).json({
      success: true,
      message: 'Ganado creado exitosamente',
      data: { id: docRef.id, ...newData }
    });
  } catch (error) {
    next(error);
  }
});

// PUT /ganado/:id - Actualizar un registro (verificando propiedad)
router.put('/:id', async function (req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.user.uid;
    const data = req.body;

    const docRef = db.collection('ganado').doc(id);
    const doc = await docRef.get();

    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'Ganado no encontrado' });
    }

    if (doc.data().usuario_id !== userId) {
      return res.status(403).json({ success: false, message: 'No tienes permiso para modificar este registro' });
    }

    const updateData = {
      ...data,
      updatedAt: new Date().toISOString()
    };

    await docRef.update(updateData);

    res.status(200).json({
      success: true,
      message: `Ganado ${id} actualizado`,
      data: { id, ...updateData }
    });
  } catch (error) {
    next(error);
  }
});

// DELETE /ganado/:id - Eliminar (verificando propiedad)
router.delete('/:id', async function (req, res, next) {
  try {
    const { id } = req.params;
    const userId = req.user.uid;

    const docRef = db.collection('ganado').doc(id);
    const doc = await docRef.get();

    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'Ganado no encontrado' });
    }

    if (doc.data().usuario_id !== userId) {
      return res.status(403).json({ success: false, message: 'No tienes permiso para eliminar este registro' });
    }

    await docRef.delete();

    res.status(200).json({
      success: true,
      message: `Ganado ${id} eliminado`
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
