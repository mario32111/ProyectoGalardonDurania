const { db } = require('../config/firebaseConfig');

class GanadoService {
    async getAll() {
        const snapshot = await db.collection('ganado').get();
        return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    }

    async getById(id) {
        const doc = await db.collection('ganado').doc(id).get();
        if (!doc.exists) return null;
        return { id: doc.id, ...doc.data() };
    }

    async create(data) {
        const newData = {
            ...data,
            createdAt: new Date().toISOString(),
            updatedAt: new Date().toISOString()
        };
        const docRef = await db.collection('ganado').add(newData);
        return { id: docRef.id, ...newData };
    }

    async update(id, data) {
        const updateData = {
            ...data,
            updatedAt: new Date().toISOString()
        };
        await db.collection('ganado').doc(id).update(updateData);
        return { id, ...updateData };
    }

    async delete(id) {
        await db.collection('ganado').doc(id).delete();
        return { id };
    }
}

module.exports = new GanadoService();
