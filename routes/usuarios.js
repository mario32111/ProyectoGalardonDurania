var express = require('express');
var router = express.Router();

/**
 * CRUD para Usuarios
 * Gestión de usuarios de la plataforma ganadera
 */

// GET /usuarios - Obtener todos los usuarios
router.get('/', function(req, res, next) {
  try {
    // TODO: Implementar lógica para obtener todos los usuarios
    res.status(200).json({
      success: true,
      message: 'Lista de usuarios',
      data: []
    });
  } catch (error) {
    next(error);
  }
});

// GET /usuarios/:id - Obtener un usuario específico
router.get('/:id', function(req, res, next) {
  try {
    const { id } = req.params;
    // TODO: Implementar lógica para obtener un usuario específico
    res.status(200).json({
      success: true,
      message: `Usuario con ID: ${id}`,
      data: {}
    });
  } catch (error) {
    next(error);
  }
});

// POST /usuarios - Crear un nuevo usuario
router.post('/', function(req, res, next) {
  try {
    const data = req.body;
    // TODO: Validar datos y crear nuevo usuario
    // Campos sugeridos: nombre, email, password, rol, telefono, etc.
    // IMPORTANTE: Hashear password antes de guardar
    res.status(201).json({
      success: true,
      message: 'Usuario creado exitosamente',
      data: data
    });
  } catch (error) {
    next(error);
  }
});

// PUT /usuarios/:id - Actualizar un usuario
router.put('/:id', function(req, res, next) {
  try {
    const { id } = req.params;
    const data = req.body;
    // TODO: Validar y actualizar el usuario
    res.status(200).json({
      success: true,
      message: `Usuario ${id} actualizado`,
      data: data
    });
  } catch (error) {
    next(error);
  }
});

// DELETE /usuarios/:id - Eliminar un usuario
router.delete('/:id', function(req, res, next) {
  try {
    const { id } = req.params;
    // TODO: Implementar lógica de eliminación
    res.status(200).json({
      success: true,
      message: `Usuario ${id} eliminado`
    });
  } catch (error) {
    next(error);
  }
});

// POST /usuarios/login - Autenticación de usuario
router.post('/login', function(req, res, next) {
  try {
    const { email, password } = req.body;
    // TODO: Implementar lógica de autenticación
    // Validar credenciales y generar token
    res.status(200).json({
      success: true,
      message: 'Login exitoso',
      token: 'token_placeholder'
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
