var express = require('express');
var router = express.Router();

/**
 * CRUD para Ganado
 * Gestión de animales de la plataforma ganadera
 */

// GET /ganado - Obtener todos los registros de ganado
router.get('/', async function (req, res, next) {
  try {
    const { db } = require('../config/firebaseConfig');
    const snapshot = await db.collection('ganado').get();
    const ganado = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    res.status(200).json({
      success: true,
      message: 'Lista de ganado',
      data: ganado
    });
  } catch (error) {
    next(error);
  }
});

// GET /ganado/:id - Obtener un registro específico de ganado
router.get('/:id', async function (req, res, next) {
  try {
    const { db } = require('../config/firebaseConfig');
    const { id } = req.params;
    const doc = await db.collection('ganado').doc(id).get();

    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'Ganado no encontrado' });
    }

    res.status(200).json({
      success: true,
      message: `Ganado con ID: ${id}`,
      data: { id: doc.id, ...doc.data() }
    });
  } catch (error) {
    next(error);
  }
});

// POST /ganado - Crear un nuevo registro de ganado
router.post('/', async function (req, res, next) {
  try {
    const { db } = require('../config/firebaseConfig');
    const data = req.body;

    // Add timestamps
    const newData = {
      ...data,
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

// PUT /ganado/:id - Actualizar un registro de ganado
router.put('/:id', async function (req, res, next) {
  try {
    const { db } = require('../config/firebaseConfig');
    const { id } = req.params;
    const data = req.body;

    const updateData = {
      ...data,
      updatedAt: new Date().toISOString()
    };

    await db.collection('ganado').doc(id).update(updateData);

    res.status(200).json({
      success: true,
      message: `Ganado ${id} actualizado`,
      data: { id, ...updateData }
    });
  } catch (error) {
    next(error);
  }
});

// DELETE /ganado/:id - Eliminar un registro de ganado
router.delete('/:id', async function (req, res, next) {
  try {
    const { db } = require('../config/firebaseConfig');
    const { id } = req.params;

    await db.collection('ganado').doc(id).delete();

    res.status(200).json({
      success: true,
      message: `Ganado ${id} eliminado`
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
