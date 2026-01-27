var express = require('express');
var router = express.Router();
const { db, admin } = require('../config/firebaseConfig');

/**
 * CRUD para Inventario
 * Gestión de inventario de la plataforma ganadera
 * (alimentos, medicamentos, equipos, etc.)
 */

// GET /inventario - Obtener todos los items del inventario
router.get('/', async function (req, res, next) {
  try {

    const snapshot = await db.collection('inventario').get();
    const items = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    res.status(200).json({
      success: true,
      message: 'Lista de inventario',
      data: items
    });
  } catch (error) {
    next(error);
  }
});

// GET /inventario/:id - Obtener un item específico del inventario
router.get('/:id', async function (req, res, next) {
  try {

    const { id } = req.params;
    const doc = await db.collection('inventario').doc(id).get();

    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'Item no encontrado' });
    }

    res.status(200).json({
      success: true,
      message: `Item con ID: ${id}`,
      data: { id: doc.id, ...doc.data() }
    });
  } catch (error) {
    next(error);
  }
});

// POST /inventario - Agregar un nuevo item al inventario
router.post('/', async function (req, res, next) {
  try {

    const data = req.body;

    // Validar datos mínimos si es necesario
    const newItem = {
      ...data,
      cantidad: Number(data.cantidad) || 0,
      createdAt: new Date().toISOString()
    };

    const docRef = await db.collection('inventario').add(newItem);

    res.status(201).json({
      success: true,
      message: 'Item agregado al inventario',
      data: { id: docRef.id, ...newItem }
    });
  } catch (error) {
    next(error);
  }
});

// PUT /inventario/:id - Actualizar un item del inventario
router.put('/:id', async function (req, res, next) {
  try {

    const { id } = req.params;
    const data = req.body;

    const updateData = { ...data, updatedAt: new Date().toISOString() };
    if (data.cantidad !== undefined) updateData.cantidad = Number(data.cantidad);

    await db.collection('inventario').doc(id).update(updateData);

    res.status(200).json({
      success: true,
      message: `Item ${id} actualizado`,
      data: { id, ...updateData }
    });
  } catch (error) {
    next(error);
  }
});

// DELETE /inventario/:id - Eliminar un item del inventario
router.delete('/:id', async function (req, res, next) {
  try {

    const { id } = req.params;

    await db.collection('inventario').doc(id).delete();

    res.status(200).json({
      success: true,
      message: `Item ${id} eliminado del inventario`
    });
  } catch (error) {
    next(error);
  }
});

// PATCH /inventario/:id/stock - Actualizar solo el stock de un item
router.patch('/:id/stock', async function (req, res, next) {
  try {

    const { id } = req.params;
    const { cantidad, operacion } = req.body; // operacion: 'agregar' o 'restar'

    const incrementValue = operacion === 'restar' ? -Math.abs(Number(cantidad)) : Math.abs(Number(cantidad));

    await db.collection('inventario').doc(id).update({
      cantidad: admin.firestore.FieldValue.increment(incrementValue),
      updatedAt: new Date().toISOString()
    });

    res.status(200).json({
      success: true,
      message: `Stock del item ${id} actualizado`,
      data: { change: incrementValue }
    });
  } catch (error) {
    next(error);
  }
});

// GET /inventario/alertas/stock-bajo - Obtener items con stock bajo
router.get('/alertas/stock-bajo', async function (req, res, next) {
  try {

    // Asumimos que los items tienen un campo 'stockMinimo', si no, usamos un default (ej. 10)
    // Firestore no permite comparar dos campos del mismo documento en una query simple (where cantidad < stockMinimo).
    // Así que obtendremos todos y filtraremos, o haremos un where cantidad < X si usamos un umbral fijo.
    // Para ser más realista, filtraremos en código si la lógica es campo vs campo.

    const snapshot = await db.collection('inventario').get();
    const items = [];
    snapshot.forEach(doc => {
      const data = doc.data();
      const stockActual = Number(data.cantidad) || 0;
      const stockMinimo = Number(data.stockMinimo) || 10; // Default 10 si no existe

      if (stockActual <= stockMinimo) {
        items.push({ id: doc.id, ...data });
      }
    });

    res.status(200).json({
      success: true,
      message: 'Items con stock bajo',
      data: items
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
