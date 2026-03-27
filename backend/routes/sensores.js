var express = require('express');
var router = express.Router();
const sensoresService = require('../services/sensoresService');
const { verifyToken } = require('../middlewares/authMiddleware');

/**
 * Rutas para Monitoreo de Sensores (Temperatura, GPS, Acelerómetro, Giroscopio)
 * Estas rutas por defecto se autentican vía JWT del usuario asociado.
 */

// POST /sensores - Recibir una nueva lectura de un sensor asociado a un animal
router.post('/', async function (req, res, next) {
    try {
        const userId = req.user.uid; // Extraído del token
        const data = req.body;
        
        const nuevaLectura = await sensoresService.registrarLectura(data, userId);

        res.status(201).json({
            success: true,
            message: 'Lectura recibida y registrada exitosamente',
            data: nuevaLectura
        });
    } catch (error) {
        res.status(400).json({
            success: false,
            message: error.message || 'Error al procesar la lectura de sensores'
        });
    }
});

// GET /sensores/animal/:animalId - Obtener histórico reciente de lecturas por animal
router.get('/animal/:animalId', async function (req, res, next) {
    try {
        const { animalId } = req.params;
        const userId = req.user.uid;
        const limit = Number(req.query.limit) || 20;

        const lecturas = await sensoresService.getLecturasPorAnimal(animalId, userId, limit);

        res.status(200).json({
            success: true,
            message: `Últimas ${lecturas.length} lecturas del animal`,
            data: lecturas
        });
    } catch (error) {
        next(error);
    }
});

// GET /sensores/actual - Obtener la lectura más reciente de todos los animales del usuario
router.get('/actual', async function (req, res, next) {
    try {
        const userId = req.user.uid;
        const estadoActual = await sensoresService.getEstadoActualAnimales(userId);

        res.status(200).json({
            success: true,
            message: 'Estado actual de monitoreo por animal',
            data: estadoActual
        });
    } catch (error) {
        next(error);
    }
});

module.exports = router;
