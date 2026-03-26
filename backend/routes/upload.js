const express = require('express');
const router = express.Router();
const multer = require('multer');
const { uploadFile, deleteFileByUrl } = require('../services/firebaseStorageService');
const tramitesService = require('../services/tramitesService');

// Configuración de multer para almacenar el archivo en memoria
const storage = multer.memoryStorage();
const upload = multer({
    storage: storage,
    limits: {
        fileSize: 10 * 1024 * 1024, // Limite de 10 MB, ajustable
    },
});

/**
 * @route POST /upload
 * @desc Sube un archivo a Firebase Storage
 * @access Public/Private dependiendo de tu middleware de autenticación
 */
router.post('/', upload.single('file'), async (req, res) => {
    try {
        const userId = req.user.uid; // Obtenido del token

        if (!req.file || !req.body.tramite_id) {
            return res.status(400).json({ success: false, message: 'Archivo y tramite_id son obligatorios.' });
        }

        const { tramite_id, folder = 'uploads' } = req.body;

        // Llamar al servicio para subir a Firebase Storage
        // Se podría añadir el userId al folder para mayor aislamiento
        const fileUrl = await uploadFile(req.file, `${userId}/${folder}`);

        // Registrar el documento en el trámite (el servicio ya verifica propiedad con userId)
        await tramitesService.addDocumento(tramite_id, {
            nombre_documento: req.file.originalname,
            tipo_documento: req.file.mimetype,
            url: fileUrl
        }, userId);

        // Avanzar la etapa del trámite
        await tramitesService.avanzarEtapa(tramite_id, {
            responsable: 'Usuario Autenticado',
            observaciones: `Documento adjuntado: ${req.file.originalname}`
        }, userId);

        res.status(200).json({
            success: true,
            message: 'Archivo subido y vinculado al trámite exitosamente.',
            url: fileUrl,
        });
    } catch (error) {
        console.error('Error en ruta /upload:', error);
        const status = error.message.includes('no autorizado') ? 403 : 500;
        res.status(status).json({ success: false, message: error.message });
    }
});

/**
 * @route DELETE /upload
 * @desc Elimina un archivo de Firebase Storage por URL (se asume que el usuario tiene el permiso si conoce la URL, 
 *       en una implementación más robusta se verificaría la pertenencia del recurso)
 */
router.delete('/', async (req, res) => {
    try {
        const { url } = req.body;
        // En un futuro: Verificar que 'url' contiene el '${userId}/' al inicio del path
        
        if (!url) {
            return res.status(400).json({ success: false, message: 'Se requiere la URL del archivo para eliminar.' });
        }

        await deleteFileByUrl(url);

        res.status(200).json({
            success: true,
            message: 'Archivo eliminado exitosamente.',
        });
    } catch (error) {
        console.error('Error en ruta DELETE /upload:', error);
        res.status(500).json({ success: false, message: 'Error al eliminar el archivo.', error: error.message });
    }
});

module.exports = router;
