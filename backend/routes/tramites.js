var express = require('express');
var router = express.Router();
const tramitesService = require('../services/tramitesService');

// GET /tramites - Obtener todos los trámites del usuario autenticado
router.get('/', async function (req, res, next) {
  try {
    const data = await tramitesService.getAll(req.query, req.user.uid);
    res.status(200).json({
      success: true,
      message: 'Lista de trámites del usuario',
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

// GET /tramites/:id - Obtener detalles de un trámite específico (verificando propiedad)
router.get('/:id', async function (req, res, next) {
  try {
    const data = await tramitesService.getById(req.params.id, req.user.uid);
    if (!data) return res.status(404).json({ success: false, message: 'Trámite no encontrado o no autorizado' });

    res.status(200).json({ success: true, message: `Trámite ${req.params.id}`, data });
  } catch (error) {
    next(error);
  }
});

// GET /tramites/:id/seguimiento - Obtener seguimiento detallado (verificando propiedad)
router.get('/:id/seguimiento', async function (req, res, next) {
  try {
    const data = await tramitesService.getSeguimiento(req.params.id, req.user.uid);
    if (!data) return res.status(404).json({ success: false, message: 'Trámite no encontrado o no autorizado' });

    res.status(200).json({ success: true, message: 'Seguimiento del trámite', data });
  } catch (error) {
    next(error);
  }
});

// POST /tramites - Crear un nuevo trámite vinculado al usuario
router.post('/', async function (req, res, next) {
  try {
    const data = await tramitesService.create(req.body, req.user.uid);
    res.status(201).json({ success: true, message: 'Trámite creado exitosamente', data });
  } catch (error) {
    if (error.message === 'Tipo de trámite no válido') {
      return res.status(400).json({ success: false, message: error.message });
    }
    next(error);
  }
});

// PUT /tramites/:id/avanzar-etapa - Avanzar a la siguiente etapa (verificando propiedad)
router.put('/:id/avanzar-etapa', async function (req, res, next) {
  try {
    const data = await tramitesService.avanzarEtapa(req.params.id, req.body, req.user.uid);
    res.status(200).json({
      success: true,
      message: 'Trámite avanzado a la siguiente etapa',
      data: { tramite_id: req.params.id, ...data }
    });
  } catch (error) {
    const msg = error.message;
    if (msg.includes('no encontrado') || msg.includes('no autorizado')) return res.status(404).json({ success: false, message: msg });
    if (msg === 'Trámite en última etapa' || msg === 'Tipo de trámite desconocido') {
      return res.status(400).json({ success: false, message: msg });
    }
    next(error);
  }
});

// PUT /tramites/:id/actualizar-etapa - Actualizar etapa específica (verificando propiedad)
router.put('/:id/actualizar-etapa', async function (req, res, next) {
  try {
    const data = await tramitesService.updateEtapa(req.params.id, req.body, req.user.uid);
    res.status(200).json({
      success: true,
      message: 'Etapa del trámite actualizada',
      data: { tramite_id: req.params.id, ...data }
    });
  } catch (error) {
    const msg = error.message;
    if (msg.includes('no encontrado') || msg.includes('no autorizado')) return res.status(404).json({ success: false, message: msg });
    if (msg === 'Etapa inválida' || msg === 'Tipo de trámite desconocido') {
      return res.status(400).json({ success: false, message: msg });
    }
    next(error);
  }
});

// PUT /tramites/:id/estado - Cambiar estado del trámite (verificando propiedad)
router.put('/:id/estado', async function (req, res, next) {
  try {
    const estadosValidos = ['EN_PROCESO', 'COMPLETADO', 'CANCELADO', 'PENDIENTE'];
    if (!estadosValidos.includes(req.body.estado)) {
      return res.status(400).json({ success: false, message: 'Estado no válido' });
    }

    const data = await tramitesService.updateEstado(req.params.id, req.body, req.user.uid);
    res.status(200).json({
      success: true,
      message: 'Estado del trámite actualizado',
      data: { tramite_id: req.params.id, ...data }
    });
  } catch (error) {
    next(error);
  }
});

// POST /tramites/:id/observaciones - Agregar observación (verificando propiedad)
router.post('/:id/observaciones', async function (req, res, next) {
  try {
    const data = await tramitesService.addObservacion(req.params.id, req.body, req.user.uid);
    res.status(200).json({ success: true, message: 'Observación agregada', data });
  } catch (error) {
    next(error);
  }
});

// POST /tramites/:id/documentos - Agregar documento (verificando propiedad)
router.post('/:id/documentos', async function (req, res, next) {
  try {
    const data = await tramitesService.addDocumento(req.params.id, req.body, req.user.uid);
    res.status(200).json({ success: true, message: 'Documento agregado al trámite', data });
  } catch (error) {
    next(error);
  }
});

// GET /tramites/:id/documentos - Obtener documentos (verificando propiedad)
router.get('/:id/documentos', async function (req, res, next) {
  try {
    const doc = await tramitesService.getById(req.params.id, req.user.uid);
    if (!doc) return res.status(404).json({ success: false, message: 'Trámite no encontrado o no autorizado' });

    res.status(200).json({
      success: true,
      message: 'Documentos del trámite',
      data: { tramite_id: req.params.id, documentos: doc.documentos || [] }
    });
  } catch (error) {
    next(error);
  }
});

// DELETE /tramites/:id - Cancelar un trámite (verificando propiedad)
router.delete('/:id', async function (req, res, next) {
  try {
    const data = await tramitesService.cancel(req.params.id, req.body, req.user.uid);
    res.status(200).json({
      success: true,
      message: 'Trámite cancelado',
      data: { tramite_id: req.params.id, ...data }
    });
  } catch (error) {
    next(error);
  }
});

// GET /tramites/estadisticas - Obtener estadísticas generales del usuario autenticado
router.get('/stats/general', async function (req, res, next) {
  try {
    const data = await tramitesService.getStats(req.user.uid);
    res.status(200).json({ success: true, message: 'Estadísticas de tus trámites', data });
  } catch (error) {
    next(error);
  }
});

module.exports = router;

module.exports = router;
