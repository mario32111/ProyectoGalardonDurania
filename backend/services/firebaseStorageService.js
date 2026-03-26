const { admin } = require('../config/firebaseConfig');
const uuid = require('uuid'); // Recomendado para generar un token de descarga único o nombres únicos, si lo utilizas.
const path = require('path');

// Obtener la referencia al bucket de Storage de forma dinámica.
const getBucket = () => {
    const BUCKET_NAME = process.env.FIREBASE_STORAGE_BUCKET;
    if (!BUCKET_NAME) {
        throw new Error('La variable de entorno FIREBASE_STORAGE_BUCKET no está configurada. Verifica tu archivo .env.');
    }
    return admin.storage().bucket(BUCKET_NAME);
};

/**
 * Sube un archivo a Firebase Storage
 * 
 * @param {Object} file - Objeto de archivo, tipicamente proveniente de req.file (Multer)
 * @param {String} folder - Carpeta destino en Storage (ej. 'imagenes', 'documentos')
 * @returns {Promise<String>} - Retorna la URL pública o firmada del archivo subido
 */
const uploadFile = async (file, folder = 'uploads') => {
    if (!file) {
        throw new Error('No se proporcionó ningún archivo para subir.');
    }

    try {
        const bucket = getBucket();
        // Generar un nombre único para el archivo para evitar colisiones
        const uniqueFilename = `${Date.now()}-${file.originalname}`;
        const destinationPath = folder ? `${folder}/${uniqueFilename}` : uniqueFilename;

        const fileUpload = bucket.file(destinationPath);

        // Opciones para configurar los metadatos y el tipo de contenido
        const blobStream = fileUpload.createWriteStream({
            metadata: {
                contentType: file.mimetype,
            },
        });

        return new Promise((resolve, reject) => {
            blobStream.on('error', (error) => {
                console.error('Error al subir el archivo a Firebase Storage:', error);
                reject(error);
            });

            blobStream.on('finish', async () => {
                try {
                    // Generar una URL firmada segura (expira en el año 2100)
                    const [url] = await fileUpload.getSignedUrl({
                        action: 'read',
                        expires: '01-01-2100',
                    });

                    resolve(url);
                } catch (error) {
                    reject('Error obteniendo la URL firmada: ' + error.message);
                }
            });

            // Escribir el buffer del archivo en el stream
            blobStream.end(file.buffer);
        });
    } catch (error) {
        throw new Error('Error interno al procesar el archivo para Firebase Storage: ' + error.message);
    }
};

/**
 * Elimina un archivo de Firebase Storage
 * 
 * @param {String} fileUrl - La URL pública del archivo a eliminar
 * @returns {Promise<Boolean>} - Retorna true si se eliminó correctamente
 */
const deleteFileByUrl = async (fileUrl) => {
    try {
        const bucket = getBucket();
        // Extraer la ruta del archivo a partir de la URL pública de Firebase Storage
        const filePathMatch = fileUrl.match(/\/o\/(.+?)\?/);
        if (!filePathMatch || !filePathMatch[1]) {
            throw new Error("No se pudo extraer la ruta del archivo desde la URL");
        }

        const filePath = decodeURIComponent(filePathMatch[1]);
        await bucket.file(filePath).delete();

        return true;
    } catch (error) {
        console.error('Error al eliminar archivo de Firebase:', error);
        throw error;
    }
}

module.exports = {
    uploadFile,
    deleteFileByUrl
};
