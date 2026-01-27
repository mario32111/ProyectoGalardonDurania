var express = require('express');
var router = express.Router();
const { db, admin } = require('../config/firebaseConfig');

/**
 * CRUD para Trámites
 * Sistema de seguimiento de trámites ganaderos con etapas
 * Tipos: Pruebas de Ganado, Movilización, Exportación
 */

// Definición de tipos de trámites y sus etapas
const TIPOS_TRAMITES = {
  PRUEBAS_GANADO: {
    nombre: 'Pruebas de Ganado',
    etapas: [
      { orden: 1, nombre: 'Solicitud Recibida', descripcion: 'Trámite registrado en el sistema' },
      { orden: 2, nombre: 'Programación de Visita', descripcion: 'Agendando fecha para toma de muestras' },
      { orden: 3, nombre: 'Toma de Muestras', descripcion: 'Veterinario tomando muestras del ganado' },
      { orden: 4, nombre: 'Muestras en Laboratorio', descripcion: 'Análisis en proceso' },
      { orden: 5, nombre: 'Resultados Disponibles', descripcion: 'Resultados listos para consulta' },
      { orden: 6, nombre: 'Finalizado', descripcion: 'Trámite completado' }
    ]
  },
  MOVILIZACION: {
    nombre: 'Trámite de Movilización',
    etapas: [
      { orden: 1, nombre: 'Solicitud Recibida', descripcion: 'Solicitud registrada' },
      { orden: 2, nombre: 'Revisión Documental', descripcion: 'Verificando documentación requerida' },
      { orden: 3, nombre: 'Inspección Sanitaria', descripcion: 'Verificación del estado sanitario del ganado' },
      { orden: 4, nombre: 'Aprobación Pendiente', descripcion: 'En revisión por autoridad competente' },
      { orden: 5, nombre: 'Guía Emitida', descripcion: 'Guía de movilización generada' },
      { orden: 6, nombre: 'Finalizado', descripcion: 'Trámite completado' }
    ]
  },
  EXPORTACION: {
    nombre: 'Trámite de Exportación',
    etapas: [
      { orden: 1, nombre: 'Solicitud Recibida', descripcion: 'Solicitud registrada' },
      { orden: 2, nombre: 'Revisión Documental', descripcion: 'Verificando documentación internacional' },
      { orden: 3, nombre: 'Certificaciones Sanitarias', descripcion: 'Obteniendo certificados requeridos' },
      { orden: 4, nombre: 'Inspección Aduanal', descripcion: 'Verificación por autoridades aduanales' },
      { orden: 5, nombre: 'Aprobación SENASA', descripcion: 'Aprobación del servicio sanitario' },
      { orden: 6, nombre: 'Documentación Lista', descripcion: 'Documentos de exportación generados' },
      { orden: 7, nombre: 'Finalizado', descripcion: 'Trámite completado' }
    ]
  }
};

// GET /tramites - Obtener todos los trámites
router.get('/', async function (req, res, next) {
  try {

    const { tipo, estado, usuario_id } = req.query;

    let query = db.collection('tramites');

    if (tipo) query = query.where('tipo', '==', tipo);
    if (estado) query = query.where('estado', '==', estado);
    if (usuario_id) query = query.where('usuario_id', '==', usuario_id);

    const snapshot = await query.get();
    const tramites = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    res.status(200).json({
      success: true,
      message: 'Lista de trámites',
      data: {
        tramites: tramites,
        total: tramites.length
      }
    });
  } catch (error) {
    next(error);
  }
});

// GET /tramites/tipos - Obtener tipos de trámites disponibles y sus etapas
router.get('/tipos', function (req, res, next) {
  try {
    res.status(200).json({
      success: true,
      message: 'Tipos de trámites disponibles',
      data: TIPOS_TRAMITES
    });
  } catch (error) {
    next(error);
  }
});

// GET /tramites/:id - Obtener detalles de un trámite específico
router.get('/:id', async function (req, res, next) {
  try {

    const { id } = req.params;
    const doc = await db.collection('tramites').doc(id).get();

    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'Trámite no encontrado' });
    }

    res.status(200).json({
      success: true,
      message: `Trámite ${id}`,
      data: { id: doc.id, ...doc.data() }
    });
  } catch (error) {
    next(error);
  }
});

// GET /tramites/:id/seguimiento - Obtener seguimiento detallado del trámite
router.get('/:id/seguimiento', async function (req, res, next) {
  try {

    const { id } = req.params;
    const doc = await db.collection('tramites').doc(id).get();

    if (!doc.exists) {
      return res.status(404).json({ success: false, message: 'Trámite no encontrado' });
    }

    const data = doc.data();

    res.status(200).json({
      success: true,
      message: 'Seguimiento del trámite',
      data: {
        tramite_id: id,
        numero_tramite: data.numero_tramite,
        tipo: data.tipo,
        estado_actual: data.estado,
        etapa_actual: data.etapa_actual,
        historial: data.historial || [],
        proxima_etapa: TIPOS_TRAMITES[data.tipo]?.etapas.find(e => e.orden === data.etapa_actual + 1) || null
      }
    });
  } catch (error) {
    next(error);
  }
});

// POST /tramites - Crear un nuevo trámite
router.post('/', async function (req, res, next) {
  try {

    const { tipo, usuario_id, ganado_ids, observaciones, documentos } = req.body;

    if (!TIPOS_TRAMITES[tipo]) {
      return res.status(400).json({
        success: false,
        message: 'Tipo de trámite no válido',
        error: `Los tipos válidos son: ${Object.keys(TIPOS_TRAMITES).join(', ')}`
      });
    }

    // Generar nuevo trámite
    const nuevoTramite = {
      numero_tramite: `TRM-2026-${String(Math.floor(Math.random() * 1000)).padStart(3, '0')}`,
      tipo: tipo,
      tipo_nombre: TIPOS_TRAMITES[tipo].nombre,
      usuario_id: usuario_id,
      ganado_ids: ganado_ids || [],
      fecha_solicitud: new Date().toISOString(),
      etapa_actual: 1,
      estado: 'PENDIENTE',
      observaciones: observaciones || '',
      documentos: documentos || [],
      historial: [{
        etapa: 1,
        nombre: 'Solicitud Recibida',
        fecha_inicio: new Date().toISOString(),
        fecha_fin: null,
        responsable: 'Sistema',
        observaciones: 'Trámite creado'
      }]
    };

    const docRef = await db.collection('tramites').add(nuevoTramite);

    res.status(201).json({
      success: true,
      message: 'Trámite creado exitosamente',
      data: { id: docRef.id, ...nuevoTramite }
    });
  } catch (error) {
    next(error);
  }
});

// PUT /tramites/:id/avanzar-etapa - Avanzar a la siguiente etapa
router.put('/:id/avanzar-etapa', async function (req, res, next) {
  try {

    const { id } = req.params;
    const { responsable, observaciones } = req.body;

    const tramitRef = db.collection('tramites').doc(id);
    const doc = await tramitRef.get();

    if (!doc.exists) return res.status(404).json({ success: false, message: 'Trámite no encontrado' });

    const data = doc.data();
    if (!TIPOS_TRAMITES[data.tipo]) return res.status(400).json({ success: false, message: 'Tipo de trámite desconocido' });

    const currentEtapa = data.etapa_actual;
    const tipoInfo = TIPOS_TRAMITES[data.tipo];

    if (currentEtapa >= tipoInfo.etapas.length) {
      return res.status(400).json({ success: false, message: 'El trámite ya está en la última etapa' });
    }

    const nextEtapaNum = currentEtapa + 1;
    const nextEtapaInfo = tipoInfo.etapas.find(e => e.orden === nextEtapaNum);

    const newHistoryItem = {
      etapa: nextEtapaNum,
      nombre: nextEtapaInfo ? nextEtapaInfo.nombre : 'Etapa desconocida',
      fecha_inicio: new Date().toISOString(),
      responsable: responsable || 'Sistema',
      observaciones: observaciones || ''
    };

    await tramitRef.update({
      etapa_actual: nextEtapaNum,
      historial: admin.firestore.FieldValue.arrayUnion(newHistoryItem),
      estado: nextEtapaNum === tipoInfo.etapas.length ? 'COMPLETADO' : 'EN_PROCESO'
    });

    res.status(200).json({
      success: true,
      message: 'Trámite avanzado a la siguiente etapa',
      data: {
        tramite_id: id,
        etapa_anterior: currentEtapa,
        etapa_actual: nextEtapaNum,
        nuevo_historial: newHistoryItem
      }
    });
  } catch (error) {
    next(error);
  }
});

// PUT /tramites/:id/actualizar-etapa - Actualizar etapa específica
router.put('/:id/actualizar-etapa', async function (req, res, next) {
  try {

    const { id } = req.params;
    const { etapa, responsable, observaciones } = req.body;

    const tramitRef = db.collection('tramites').doc(id);
    const doc = await tramitRef.get();

    if (!doc.exists) return res.status(404).json({ success: false, message: 'Trámite no encontrado' });
    const data = doc.data();
    if (!TIPOS_TRAMITES[data.tipo]) return res.status(400).json({ success: false, message: 'Tipo de trámite desconocido' });

    const tipoInfo = TIPOS_TRAMITES[data.tipo];
    if (etapa < 1 || etapa > tipoInfo.etapas.length) {
      return res.status(400).json({ success: false, message: 'Número de etapa inválido' });
    }
    const etapaInfo = tipoInfo.etapas.find(e => e.orden === etapa);

    const historyUpdate = {
      etapa: etapa,
      nombre: etapaInfo ? etapaInfo.nombre : 'Etapa ' + etapa,
      fecha_actualizacion: new Date().toISOString(),
      responsable: responsable || 'Admin',
      observaciones: observaciones || 'Actualización manual de etapa'
    };

    await tramitRef.update({
      etapa_actual: etapa,
      historial: admin.firestore.FieldValue.arrayUnion(historyUpdate)
    });

    res.status(200).json({
      success: true,
      message: 'Etapa del trámite actualizada',
      data: {
        tramite_id: id,
        etapa_actual: etapa,
        responsable,
        observaciones
      }
    });
  } catch (error) {
    next(error);
  }
});

// PUT /tramites/:id/estado - Cambiar estado del trámite
router.put('/:id/estado', async function (req, res, next) {
  try {

    const { id } = req.params;
    const { estado, motivo } = req.body;

    const estadosValidos = ['EN_PROCESO', 'COMPLETADO', 'CANCELADO', 'PENDIENTE'];
    if (!estadosValidos.includes(estado)) {
      return res.status(400).json({ success: false, message: 'Estado no válido' });
    }

    const historyItem = {
      tipo: 'CAMBIO_ESTADO',
      nuevo_estado: estado,
      motivo: motivo || '',
      fecha: new Date().toISOString()
    };

    await db.collection('tramites').doc(id).update({
      estado: estado,
      historial: admin.firestore.FieldValue.arrayUnion(historyItem)
    });

    res.status(200).json({
      success: true,
      message: 'Estado del trámite actualizado',
      data: { tramite_id: id, nuevo_estado: estado }
    });
  } catch (error) {
    next(error);
  }
});

// POST /tramites/:id/observaciones - Agregar observación al trámite
router.post('/:id/observaciones', async function (req, res, next) {
  try {

    const { id } = req.params;
    const { observacion, usuario } = req.body;

    const newObs = {
      observacion,
      usuario,
      fecha: new Date().toISOString()
    };

    await db.collection('tramites').doc(id).update({
      observaciones_list: admin.firestore.FieldValue.arrayUnion(newObs)
    });

    res.status(200).json({
      success: true,
      message: 'Observación agregada',
      data: newObs
    });
  } catch (error) {
    next(error);
  }
});

// POST /tramites/:id/documentos - Agregar documento al trámite
router.post('/:id/documentos', async function (req, res, next) {
  try {

    const { id } = req.params;
    const { nombre_documento, tipo_documento, url } = req.body;

    const newDoc = {
      nombre: nombre_documento,
      tipo: tipo_documento,
      url: url,
      fecha_subida: new Date().toISOString()
    };

    await db.collection('tramites').doc(id).update({
      documentos: admin.firestore.FieldValue.arrayUnion(newDoc)
    });

    res.status(200).json({
      success: true,
      message: 'Documento agregado al trámite',
      data: newDoc
    });
  } catch (error) {
    next(error);
  }
});

// GET /tramites/:id/documentos - Obtener documentos del trámite
router.get('/:id/documentos', async function (req, res, next) {
  try {

    const { id } = req.params;

    const doc = await db.collection('tramites').doc(id).get();
    if (!doc.exists) return res.status(404).json({ success: false, message: 'Trámite no encontrado' });

    res.status(200).json({
      success: true,
      message: 'Documentos del trámite',
      data: {
        tramite_id: id,
        documentos: doc.data().documentos || []
      }
    });
  } catch (error) {
    next(error);
  }
});

// DELETE /tramites/:id - Cancelar un trámite
router.delete('/:id', async function (req, res, next) {
  try {

    const { id } = req.params;
    const { motivo } = req.body;

    const historyItem = {
      tipo: 'CANCELACION',
      motivo: motivo || 'Cancelado por usuario',
      fecha: new Date().toISOString()
    };

    await db.collection('tramites').doc(id).update({
      estado: 'CANCELADO',
      historial: admin.firestore.FieldValue.arrayUnion(historyItem)
    });

    res.status(200).json({
      success: true,
      message: 'Trámite cancelado',
      data: { tramite_id: id, estado: 'CANCELADO' }
    });
  } catch (error) {
    next(error);
  }
});

// GET /tramites/usuario/:usuario_id - Obtener trámites de un usuario específico
router.get('/usuario/:usuario_id', async function (req, res, next) {
  try {

    const { usuario_id } = req.params;

    const snapshot = await db.collection('tramites').where('usuario_id', '==', usuario_id).get();
    const tramites = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

    res.status(200).json({
      success: true,
      message: `Trámites del usuario ${usuario_id}`,
      data: {
        usuario_id: usuario_id,
        tramites: tramites,
        total: tramites.length
      }
    });
  } catch (error) {
    next(error);
  }
});

// GET /tramites/estadisticas - Obtener estadísticas generales de trámites
router.get('/stats/general', async function (req, res, next) {
  try {


    const snapshot = await db.collection('tramites').get();
    const total = snapshot.size;

    const stats = {
      total_tramites: total,
      por_tipo: {},
      por_estado: {}
    };

    snapshot.forEach(doc => {
      const d = doc.data();
      stats.por_tipo[d.tipo] = (stats.por_tipo[d.tipo] || 0) + 1;
      stats.por_estado[d.estado] = (stats.por_estado[d.estado] || 0) + 1;
    });

    res.status(200).json({
      success: true,
      message: 'Estadísticas de trámites',
      data: stats
    });
  } catch (error) {
    next(error);
  }
});

module.exports = router;
