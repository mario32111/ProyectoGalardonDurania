const { db } = require('../config/firebaseConfig');

class ChatbotService {
    async getHistorial(usuario_id, limite = 50) {
        const snapshot = await db.collection('sesiones')
            .where('usuario_id', '==', usuario_id)
            .orderBy('fecha_inicio', 'desc')
            .limit(Number(limite))
            .get();
        return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    }

    async getSesion(sesion_id) {
        const doc = await db.collection('sesiones').doc(sesion_id).get();
        if (!doc.exists) return null;
        return { sesion_id: doc.id, ...doc.data() };
    }

    async createSesion(usuario_id) {
        const nuevaSesion = {
            usuario_id,
            fecha_inicio: new Date().toISOString(),
            mensajes: []
        };
        const docRef = await db.collection('sesiones').add(nuevaSesion);
        return { sesion_id: docRef.id, ...nuevaSesion };
    }

    async deleteSesion(sesion_id) {
        await db.collection('sesiones').doc(sesion_id).delete();
        return { sesion_id };
    }

    async saveFeedback(data) {
        const feedbackData = {
            ...data,
            fecha: new Date().toISOString()
        };
        await db.collection('feedback_chatbot').add(feedbackData);
        return feedbackData;
    }
}

module.exports = new ChatbotService();
