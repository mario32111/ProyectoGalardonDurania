var express = require('express');
var router = express.Router();
const tramitesService = require('../services/tramitesService');

// GET /tramites - Obtener todos los trámites
router.get('/', async function (req, res, next) {
  try {
    const data = await tramitesService.getAll(req.query);
    res.status(200).json({
      success: true,
      message: 'Lista de trámites',
      data: { tramites: data, total: data.length }
    });
  } catch (error) {
    next(error);
  }
});

// GET /tramites/tipos - Obtener tipos de trámites disponibles y sus etapas
router.get('/tipos', function (req, res, next) {
  try {
    const data = tramitesService.getTipos();
    res.status(200).json({ success: true, message: 'Tipos de trámites disponibles', data });
  } catch (error) {
    next(error);
  }
});

// GET /tramites/:id - Obtener detalles de un trámite específico
router.get('/:id', async function (req, res, next) {
  try {
    const data = await tramitesService.getById(req.params.id);
    if (!data) return res.status(404).json({ success: false, message: 'Trámite no encontrado' });

    res.status(200).json({ success: true, message: `Trámite ${req.params.id}`, data });
  } catch (error) {
    next(error);
  }
});

// GET /tramites/:id/seguimiento - Obtener seguimiento detallado del trámite
router.get('/:id/seguimiento', async function (req, res, next) {
  try {
    const data = await tramitesService.getSeguimiento(req.params.id);
    if (!data) return res.status(404).json({ success: false, message: 'Trámite no encontrado' });

    res.status(200).json({ success: true, message: 'Seguimiento del trámite', data });
  } catch (error) {
    next(error);
  }
});

// POST /tramites - Crear un nuevo trámite
router.post('/', async function (req, res, next) {
  try {
    const data = await tramitesService.create(req.body);
    res.status(201).json({ success: true, message: 'Trámite creado exitosamente', data });
  } catch (error) {
    if (error.message === 'Tipo de trámite no válido') {
      return res.status(400).json({ success: false, message: error.message });
    }
    next(error);
  }
});

// PUT /tramites/:id/avanzar-etapa - Avanzar a la siguiente etapa
router.put('/:id/avanzar-etapa', async function (req, res, next) {
  try {
    const data = await tramitesService.avanzarEtapa(req.params.id, req.body);
    res.status(200).json({
      success: true,
      message: 'Trámite avanzado a la siguiente etapa',
      data: { tramite_id: req.params.id, ...data }
    });
  } catch (error) {
    if (error.message === 'Trámite no encontrado') return res.status(404).json({ success: false, message: error.message });
    if (error.message === 'Trámite en última etapa' || error.message === 'Tipo de trámite desconocido') {
      return res.status(400).json({ success: false, message: error.message });
    }
    next(error);
  }
});

// PUT /tramites/:id/actualizar-etapa - Actualizar etapa específica
router.put('/:id/actualizar-etapa', async function (req, res, next) {
  try {
    const data = await tramitesService.updateEtapa(req.params.id, req.body);
    res.status(200).json({
      success: true,
      message: 'Etapa del trámite actualizada',
      data: { tramite_id: req.params.id, ...data }
    });
  } catch (error) {
    if (error.message === 'Trámite no encontrado') return res.status(404).json({ success: false, message: error.message });
    if (error.message === 'Etapa inválida' || error.message === 'Tipo de trámite desconocido') {
      return res.status(400).json({ success: false, message: error.message });
    }
    next(error);
  }
});

// PUT /tramites/:id/estado - Cambiar estado del trámite
router.put('/:id/estado', async function (req, res, next) {
  try {
    const estadosValidos = ['EN_PROCESO', 'COMPLETADO', 'CANCELADO', 'PENDIENTE'];
    if (!estadosValidos.includes(req.body.estado)) {
      return res.status(400).json({ success: false, message: 'Estado no válido' });
    }

    const data = await tramitesService.updateEstado(req.params.id, req.body);
    res.status(200).json({
      success: true,
      message: 'Estado del trámite actualizado',
      data: { tramite_id: req.params.id, ...data }
    });
  } catch (error) {
    next(error);
  }
});

// POST /tramites/:id/observaciones - Agregar observación al trámite
router.post('/:id/observaciones', async function (req, res, next) {
  try {
    const data = await tramitesService.addObservacion(req.params.id, req.body);
    res.status(200).json({ success: true, message: 'Observación agregada', data });
  } catch (error) {
    next(error);
  }
});

// POST /tramites/:id/documentos - Agregar documento al trámite
router.post('/:id/documentos', async function (req, res, next) {
  try {
    const data = await tramitesService.addDocumento(req.params.id, req.body);
    res.status(200).json({ success: true, message: 'Documento agregado al trámite', data });
  } catch (error) {
    next(error);
  }
});

// GET /tramites/:id/documentos - Obtener documentos del trámite
router.get('/:id/documentos', async function (req, res, next) {
  try {
    const doc = await tramitesService.getById(req.params.id);
    if (!doc) return res.status(404).json({ success: false, message: 'Trámite no encontrado' });

    res.status(200).json({
      success: true,
      message: 'Documentos del trámite',
      data: { tramite_id: req.params.id, documentos: doc.documentos || [] }
    });
  } catch (error) {
    next(error);
  }
});

// DELETE /tramites/:id - Cancelar un trámite
router.delete('/:id', async function (req, res, next) {
  try {
    const data = await tramitesService.cancel(req.params.id, req.body);
    res.status(200).json({
      success: true,
      message: 'Trámite cancelado',
      data: { tramite_id: req.params.id, ...data }
    });
  } catch (error) {
    next(error);
  }
});

// GET /tramites/usuario/:usuario_id - Obtener trámites de un usuario específico
router.get('/usuario/:usuario_id', async function (req, res, next) {
  try {
    const tramites = await tramitesService.getAll({ usuario_id: req.params.usuario_id });
    res.status(200).json({
      success: true,
      message: `Trámites del usuario ${req.params.usuario_id}`,
      data: { usuario_id: req.params.usuario_id, tramites, total: tramites.length }
    });
  } catch (error) {
    next(error);
  }
});

// GET /tramites/estadisticas - Obtener estadísticas generales de trámites
router.get('/stats/general', async function (req, res, next) {
  try {
    const data = await tramitesService.getStats();
    res.status(200).json({ success: true, message: 'Estadísticas de trámites', data });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
