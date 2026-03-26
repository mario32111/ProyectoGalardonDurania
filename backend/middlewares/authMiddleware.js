const { admin } = require('../config/firebaseConfig');

/**
 * Middleware para verificar el Firebase ID Token enviado en los headers.
 * Se espera: Authorization: Bearer <token>
 */
const verifyToken = async (req, res, next) => {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({
            success: false,
            message: 'No se proporcionó un token de autenticación válido (Bearer <token>).'
        });
    }

    const idToken = authHeader.split('Bearer ')[1];

    try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        req.user = decodedToken; // uid estará en req.user.uid
        next();
    } catch (error) {
        console.error('Error al verificar token de Firebase:', error.message);
        return res.status(401).json({
            success: false,
            message: 'Token de autenticación inválido o expirado.',
            error: error.message
        });
    }
};

module.exports = { verifyToken };
