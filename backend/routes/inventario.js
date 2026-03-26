var express = require('express');
var router = express.Router();
const inventarioService = require('../services/inventarioService');

// GET /inventario - Obtener todos los items
router.get('/', async function (req, res, next) {
  try {
    const data = await inventarioService.getAll();
    res.status(200).json({ success: true, message: 'Lista de inventario', data });
  } catch (error) {
    next(error);
  }
});

// GET /inventario/:id - Obtener item
router.get('/:id', async function (req, res, next) {
  try {
    const data = await inventarioService.getById(req.params.id);
    if (!data) return res.status(404).json({ success: false, message: 'Item no encontrado' });

    res.status(200).json({ success: true, message: `Item con ID: ${req.params.id}`, data });
  } catch (error) {
    next(error);
  }
});

// POST /inventario - Crear item
router.post('/', async function (req, res, next) {
  try {
    const data = await inventarioService.create(req.body);
    res.status(201).json({ success: true, message: 'Item agregado', data });
  } catch (error) {
    next(error);
  }
});

// PUT /inventario/:id - Actualizar item
router.put('/:id', async function (req, res, next) {
  try {
    const data = await inventarioService.update(req.params.id, req.body);
    res.status(200).json({ success: true, message: `Item ${req.params.id} actualizado`, data });
  } catch (error) {
    next(error);
  }
});

// DELETE /inventario/:id - Eliminar item
router.delete('/:id', async function (req, res, next) {
  try {
    await inventarioService.delete(req.params.id);
    res.status(200).json({ success: true, message: `Item ${req.params.id} eliminado` });
  } catch (error) {
    next(error);
  }
});

// PATCH /inventario/:id/stock - Actualizar stock
router.patch('/:id/stock', async function (req, res, next) {
  try {
    const { cantidad, operacion } = req.body;
    const data = await inventarioService.updateStock(req.params.id, cantidad, operacion);
    res.status(200).json({ success: true, message: `Stock actualizado`, data });
  } catch (error) {
    next(error);
  }
});

// GET /inventario/alertas/stock-bajo
router.get('/alertas/stock-bajo', async function (req, res, next) {
  try {
    const data = await inventarioService.getStockBajo();
    res.status(200).json({ success: true, message: 'Items con stock bajo', data });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
