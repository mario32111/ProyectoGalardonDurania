const { db } = require('../config/firebaseConfig');

class UsuariosService {
    async getAll() {
        const snapshot = await db.collection('usuarios').get();
        return snapshot.docs.map(doc => {
            const data = doc.data();
            delete data.password;
            return { id: doc.id, ...data };
        });
    }

    async getById(id) {
        const doc = await db.collection('usuarios').doc(id).get();
        if (!doc.exists) return null;

        const data = doc.data();
        delete data.password;
        return { id: doc.id, ...data };
    }

    async create(data) {
        const emailCheck = await db.collection('usuarios').where('email', '==', data.email).get();
        if (!emailCheck.empty) {
            throw new Error('El email ya está registrado');
        }

        const newUser = {
            ...data,
            createdAt: new Date().toISOString()
        };

        const docRef = await db.collection('usuarios').add(newUser);
        delete newUser.password;
        return { id: docRef.id, ...newUser };
    }

    async update(id, data) {
        const updateData = { ...data, updatedAt: new Date().toISOString() };
        await db.collection('usuarios').doc(id).update(updateData);
        delete updateData.password;
        return { id, ...updateData };
    }

    async delete(id) {
        await db.collection('usuarios').doc(id).delete();
        return { id };
    }

    async login(email, password) {
        const users = await db.collection('usuarios').where('email', '==', email).limit(1).get();
        if (users.empty) return null;

        const userDoc = users.docs[0];
        const userData = userDoc.data();

        // En producción usar bcrypt
        if (userData.password !== password) return null;

        return {
            token: userDoc.id, // Placeholder token
            user: {
                id: userDoc.id,
                email: userData.email,
                nombre: userData.nombre,
                rol: userData.rol
            }
        };
    }
}

module.exports = new UsuariosService();
