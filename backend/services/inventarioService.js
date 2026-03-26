const { db, admin } = require('../config/firebaseConfig');

class InventarioService {
    async getAll(userId) {
        const snapshot = await db.collection('inventario')
            .where('usuario_id', '==', userId)
            .get();
        return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    }

    async getById(id, userId) {
        const doc = await db.collection('inventario').doc(id).get();
        if (!doc.exists) return null;
        const data = doc.data();
        if (data.usuario_id !== userId) return null; // Verificación de propiedad
        return { id: doc.id, ...data };
    }

    async create(data, userId) {
        const newItem = {
            ...data,
            usuario_id: userId, // Vincular al usuario
            cantidad: Number(data.cantidad) || 0,
            createdAt: new Date().toISOString()
        };
        const docRef = await db.collection('inventario').add(newItem);
        return { id: docRef.id, ...newItem };
    }

    async update(id, data, userId) {
        const docRef = db.collection('inventario').doc(id);
        const doc = await docRef.get();
        
        if (!doc.exists || doc.data().usuario_id !== userId) {
            throw new Error('No autorizado o item no encontrado');
        }

        const updateData = { ...data, updatedAt: new Date().toISOString() };
        if (data.cantidad !== undefined) updateData.cantidad = Number(data.cantidad);

        await docRef.update(updateData);
        return { id, ...updateData };
    }

    async delete(id, userId) {
        const docRef = db.collection('inventario').doc(id);
        const doc = await docRef.get();

        if (!doc.exists || doc.data().usuario_id !== userId) {
            throw new Error('No autorizado o item no encontrado');
        }

        await docRef.delete();
        return { id };
    }

    async updateStock(id, cantidad, operacion, userId) {
        const docRef = db.collection('inventario').doc(id);
        const doc = await docRef.get();

        if (!doc.exists || doc.data().usuario_id !== userId) {
            throw new Error('No autorizado o item no encontrado');
        }

        const incrementValue = operacion === 'restar' ? -Math.abs(Number(cantidad)) : Math.abs(Number(cantidad));

        await docRef.update({
            cantidad: admin.firestore.FieldValue.increment(incrementValue),
            updatedAt: new Date().toISOString()
        });

        return { change: incrementValue };
    }

    async getStockBajo(userId, limite = 10) {
        const snapshot = await db.collection('inventario')
            .where('usuario_id', '==', userId)
            .get();
            
        const items = [];
        snapshot.forEach(doc => {
            const data = doc.data();
            const stockActual = Number(data.cantidad) || 0;
            const stockMinimo = Number(data.stockMinimo) || limite;

            if (stockActual <= stockMinimo) {
                items.push({ id: doc.id, ...data });
            }
        });
        return items;
    }
}

module.exports = new InventarioService();
