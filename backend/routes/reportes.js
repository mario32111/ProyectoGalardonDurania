var express = require('express');
var router = express.Router();
const { db } = require('../config/firebaseConfig');

/**
 * GET /reportes/ganado/individual/:arete
 * Obtiene el historial completo de un animal (datos, salud, monitoreo).
 */
router.get('/ganado/individual/:arete', async (req, res, next) => {
  try {
    const { arete } = req.params;
    const userId = req.user.uid;

    // 1. Buscar en la colección 'ganado'
    const ganadoSnapshot = await db.collection('ganado')
      .where('usuario_id', '==', userId)
      .where('arete_siniiga', '==', arete)
      .limit(1)
      .get();

    if (ganadoSnapshot.empty) {
      return res.status(404).json({ success: false, message: 'Animal no encontrado' });
    }

    const animalData = { id: ganadoSnapshot.docs[0].id, ...ganadoSnapshot.docs[0].data() };

    // 2. Obtener reportes de salud
    const saludSnapshot = await db.collection('reportes_salud')
      .where('usuario_id', '==', userId)
      .where('animal_id', '==', animalData.id)
      .get();
    
    // Si no tiene animal_id, puede que se haya guardado con arete
    const saludPorAreteSnapshot = await db.collection('reportes_salud')
      .where('usuario_id', '==', userId)
      .where('arete_siniiga', '==', arete)
      .get();

    let historialSalud = [
      ...saludSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() })),
      ...saludPorAreteSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }))
    ];

    // Ordenar manualmente por fecha
    historialSalud.sort((a, b) => {
      const d1 = b.fecha_registro?._seconds || 0;
      const d2 = a.fecha_registro?._seconds || 0;
      return d1 - d2;
    });

    // 2.5 Obtener eventos críticos
    const eventosSnapshot = await db.collection('eventos_criticos')
      .where('usuario_id', '==', userId)
      .where('arete_siniiga', '==', arete)
      .get();

    let historialEventos = eventosSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    historialEventos.sort((a, b) => {
      const d1 = b.fecha_registro?._seconds || 0;
      const d2 = a.fecha_registro?._seconds || 0;
      return d1 - d2;
    });

    // 3. Obtener datos de monitoreo (últimos 30 registros proxy)
    const monitoreoSnapshot = await db.collection('monitoreo')
      .where('usuario_id', '==', userId)
      .where('animal_id', '==', animalData.id)
      .get();

    let historialMonitoreo = monitoreoSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    
    // Ordenar manualmente
    historialMonitoreo.sort((a, b) => {
      const d1 = b.timestamp ? new Date(b.timestamp).getTime() : (b.timestamp?._seconds * 1000 || 0);
      const d2 = a.timestamp ? new Date(a.timestamp).getTime() : (a.timestamp?._seconds * 1000 || 0);
      return d1 - d2;
    });
    
    historialMonitoreo = historialMonitoreo.slice(0, 30);

    res.status(200).json({
      success: true,
      data: {
        animal: animalData,
        salud: historialSalud,
        eventos: historialEventos,
        monitoreo: historialMonitoreo
      }
    });

  } catch (error) {
    next(error);
  }
});

/**
 * GET /reportes/ganado/lotes
 * Obtiene datos agregados de compras y ventas de lotes.
 */
router.get('/ganado/lotes', async (req, res, next) => {
  try {
    const userId = req.user.uid;

    // Obtener Compras
    const comprasSnapshot = await db.collection('compras_lotes')
      .where('usuario_id', '==', userId)
      .get();
    
    let compras = comprasSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    compras.sort((a, b) => (b.fecha_registro_sistema?._seconds || 0) - (a.fecha_registro_sistema?._seconds || 0));

    // Obtener Ventas
    const ventasSnapshot = await db.collection('ventas_salidas')
      .where('usuario_id', '==', userId)
      .get();
    
    let ventas = ventasSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    ventas.sort((a, b) => (b.fecha_registro_sistema?._seconds || 0) - (a.fecha_registro_sistema?._seconds || 0));

    // Calcular totales
    let totalCabezasCompradas = 0;
    let montoTotalInvertido = 0;
    compras.forEach(c => {
      totalCabezasCompradas += (c.cantidad_cabezas || 0);
      montoTotalInvertido += (c.total_pagado || 0);
    });

    let totalCabezasVendidas = 0;
    let montoTotalVendido = 0;
    ventas.forEach(v => {
      totalCabezasVendidas += (v.cantidad_cabezas || 0);
      montoTotalVendido += (v.monto_total || 0);
    });

    res.status(200).json({
      success: true,
      data: {
        resumen: {
          compras: { cabezas: totalCabezasCompradas, monto: montoTotalInvertido },
          ventas: { cabezas: totalCabezasVendidas, monto: montoTotalVendido },
          balance: montoTotalVendido - montoTotalInvertido
        },
        compras_detalle: compras,
        ventas_detalle: ventas
      }
    });

  } catch (error) {
    next(error);
  }
});

/**
 * POST /reportes/evento-critico
 * Endpoint para recibir y registrar eventos críticos desde otras plataformas o dispositivos automatizados.
 * Body esperado: { "arete_siniiga": "MX-123", "tipo_evento": "Movilización", "descripcion": "...", "origen": "API Automática" }
 */
router.post('/evento-critico', async (req, res, next) => {
  try {
    const userId = req.user.uid;
    const { arete_siniiga, tipo_evento, descripcion, origen } = req.body;

    if (!arete_siniiga || !tipo_evento || !descripcion) {
      return res.status(400).json({ success: false, message: 'Faltan parámetros requeridos (arete_siniiga, tipo_evento, descripcion)' });
    }

    const nuevoEvento = {
      usuario_id: userId,
      arete_siniiga: arete_siniiga.trim(),
      tipo_evento: tipo_evento.trim(),
      descripcion: descripcion.trim(),
      fecha_registro: new Date(), // En el server usamos Date que se traduce automáticametne para Firestore
      origen: origen || 'API REST Automática'
    };

    const docRef = await db.collection('eventos_criticos').add(nuevoEvento);

    res.status(201).json({
      success: true,
      message: 'Evento Crítico registrado exitosamente.',
      data: { id: docRef.id, ...nuevoEvento }
    });

  } catch (error) {
    next(error);
  }
});

module.exports = router;
