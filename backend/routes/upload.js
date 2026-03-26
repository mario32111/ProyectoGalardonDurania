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
        if (!req.file || !req.body.tramite_id) {
            return res.status(400).json({ success: false, message: 'Ningún archivo proporcionado.' });
        }

        // Carpeta destino opcional si se envía por body (ej. "ganado", "usuarios")
        const folder = req.body.folder || 'uploads';
        const { tramite_id } = req.body;

        // Llamar al servicio
        const fileUrl = await uploadFile(req.file, folder);

        if (tramite_id) {
            // Registrar el documento en el trámite utilizando el servicio
            await tramitesService.addDocumento(tramite_id, {
                nombre_documento: req.file.originalname,
                tipo_documento: req.file.mimetype,
                url: fileUrl
            });

            // Avanzar la etapa del trámite utilizando el servicio
            await tramitesService.avanzarEtapa(tramite_id, {
                responsable: req.body.usuario_id || 'Sistema',
                observaciones: `Documento adjuntado: ${req.file.originalname}`
            });
        }

        res.status(200).json({
            success: true,
            message: 'Archivo subido exitosamente.',
            url: fileUrl,
        });
    } catch (error) {
        console.error('Error en ruta /upload:', error);
        res.status(500).json({ success: false, message: 'Error interno del servidor al subir archivo.', error: error.message });
    }
});

/**
 * @route DELETE /upload
 * @desc Elimina un archivo de Firebase Storage por URL
 */
router.delete('/', async (req, res) => {
    try {
        const { url } = req.body;

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
