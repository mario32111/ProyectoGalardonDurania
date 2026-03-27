const express = require('express');
const router = express.Router();
const multer = require('multer');
const { uploadFile, deleteFileByUrl } = require('../services/firebaseStorageService');
const tramitesService = require('../services/tramitesService');
const openAIService = require('../services/openAIService');
const notificationService = require('../services/notificationService');

// Configuración de multer para almacenar el archivo en memoria
const storage = multer.memoryStorage();
const upload = multer({
    storage: storage,
    limits: {
        fileSize: 50 * 1024 * 1024, // Limite de 50 MB para fotos pesadas
    },
});

/**
 * @route POST /upload
 * @desc Sube un archivo a Firebase Storage, lo analiza con IA y notifica al usuario
 */
router.post('/', upload.single('file'), async (req, res) => {
    try {
        const userId = req.user.uid; 

        if (!req.file || !req.body.tramite_id) {
            return res.status(400).json({ success: false, message: 'Archivo y tramite_id son obligatorios.' });
        }

        const { tramite_id, folder = 'uploads' } = req.body;

        // 1. Subir a Firebase Storage
        const fileUrl = await uploadFile(req.file, `${userId}/${folder}`);

        // 2. Análisis con IA (en paralelo o secuencial, aquí secuencial para asegurar datos)
        const analisisIa = await openAIService.analyzeDocument(fileUrl, req.file.originalname);

        // 3. Registrar el documento en el trámite con los resultados de la IA
        await tramitesService.addDocumento(tramite_id, {
            nombre_documento: req.file.originalname,
            tipo_documento: req.file.mimetype,
            url: fileUrl,
            analisis_ia: analisisIa
        }, userId);

        // 4. Avanzar la etapa del trámite
        await tramitesService.avanzarEtapa(tramite_id, {
            responsable: 'Sistema (IA Analysis)',
            observaciones: `Documento adjuntado y analizado: ${req.file.originalname}. Resultado IA: ${analisisIa.legible ? 'Legible' : 'Ilegible'}`
        }, userId);

        // 5. Enviar notificación push con el resultado
        const tipoNotificacion = (analisisIa.legible && analisisIa.veraz) ? 'info' : 'advertencia';
        const tituloNoti = analisisIa.veraz ? '✅ Documento Recibido' : '⚠️ Observación en Documento';
        const msgNoti = `El análisis de "${req.file.originalname}" indica: ${analisisIa.observaciones}`;

        await notificationService.sendToUser(userId, {
            titulo: tituloNoti,
            mensaje: msgNoti,
            tipo: tipoNotificacion,
            data: { tramite_id, screen: 'detalle_tramite' }
        }).catch(err => console.error('Error enviando notificación post-upload:', err));

        res.status(200).json({
            success: true,
            message: 'Archivo subido, analizado y vinculado exitosamente.',
            url: fileUrl,
            analisis: analisisIa
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
