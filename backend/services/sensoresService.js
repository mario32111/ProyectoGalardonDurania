const { db } = require('../config/firebaseConfig');

class SensoresService {
    /**
     * Registra una nueva lectura de sensores (temperatura, gps, acelerometro, giroscopio).
     * @param {Object} data - Datos de la lectura.
     * @param {string} userId - ID del usuario dueño del animal/dispositivo.
     */
    async registrarLectura(data, userId) {
        const { animal_id, temperatura, gps, acelerometro, giroscopio } = data;

        if (!animal_id) {
            throw new Error('animal_id es requerido');
        }

        const nuevaLectura = {
            animal_id,
            usuario_id: userId,
            temperatura: Number(temperatura) || 0,
            gps: {
                lat: Number(gps?.lat) || 0,
                lng: Number(gps?.lng) || 0
            },
            acelerometro: {
                x: Number(acelerometro?.x) || 0,
                y: Number(acelerometro?.y) || 0,
                z: Number(acelerometro?.z) || 0
            },
            giroscopio: {
                x: Number(giroscopio?.x) || 0,
                y: Number(giroscopio?.y) || 0,
                z: Number(giroscopio?.z) || 0
            },
            timestamp: new Date().toISOString()
        };

        const docRef = await db.collection('monitoreo').add(nuevaLectura);
        
        // Opcionalmente, podemos actualizar el último estado conocido del animal en la colección 'ganado'
        await db.collection('ganado').doc(animal_id).update({
            ultima_lectura: nuevaLectura,
            updatedAt: new Date().toISOString()
        }).catch(err => {
            console.warn(`No se pudo actualizar el estado del animal ${animal_id}:`, err.message);
        });

        return { id: docRef.id, ...nuevaLectura };
    }

    /**
     * Obtiene las últimas lecturas de un animal específico.
     * @param {string} animalId - ID del animal.
     * @param {string} userId - ID del usuario para validación.
     * @param {number} limit - Cantidad de registros a retornar.
     */
    async getLecturasPorAnimal(animalId, userId, limit = 20) {
        const snapshot = await db.collection('monitoreo')
            .where('animal_id', '==', animalId)
            .where('usuario_id', '==', userId)
            .orderBy('timestamp', 'desc')
            .limit(limit)
            .get();

        return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    }

    /**
     * Obtiene la lectura más reciente de todos los animales de un usuario.
     * @param {string} userId - ID del usuario.
     */
    async getEstadoActualAnimales(userId) {
        const snapshot = await db.collection('ganado')
            .where('usuario_id', '==', userId)
            .get();

        const animales = snapshot.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                nombre: data.nombre || 'Sin nombre',
                ultima_lectura: data.ultima_lectura || null
            };
        });

        return animales;
    }
}

module.exports = new SensoresService();
