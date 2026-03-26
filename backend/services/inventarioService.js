const { db, admin } = require('../config/firebaseConfig');

class InventarioService {
    async getAll() {
        const snapshot = await db.collection('inventario').get();
        return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    }

    async getById(id) {
        const doc = await db.collection('inventario').doc(id).get();
        if (!doc.exists) return null;
        return { id: doc.id, ...doc.data() };
    }

    async create(data) {
        const newItem = {
            ...data,
            cantidad: Number(data.cantidad) || 0,
            createdAt: new Date().toISOString()
        };
        const docRef = await db.collection('inventario').add(newItem);
        return { id: docRef.id, ...newItem };
    }

    async update(id, data) {
        const updateData = { ...data, updatedAt: new Date().toISOString() };
        if (data.cantidad !== undefined) updateData.cantidad = Number(data.cantidad);

        await db.collection('inventario').doc(id).update(updateData);
        return { id, ...updateData };
    }

    async delete(id) {
        await db.collection('inventario').doc(id).delete();
        return { id };
    }

    async updateStock(id, cantidad, operacion) {
        const incrementValue = operacion === 'restar' ? -Math.abs(Number(cantidad)) : Math.abs(Number(cantidad));

        await db.collection('inventario').doc(id).update({
            cantidad: admin.firestore.FieldValue.increment(incrementValue),
            updatedAt: new Date().toISOString()
        });

        return { change: incrementValue };
    }

    async getStockBajo(limite = 10) {
        const snapshot = await db.collection('inventario').get();
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
