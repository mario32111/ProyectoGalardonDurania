const { db, admin } = require('../config/firebaseConfig');
const TIPOS_TRAMITES = require('../utils/tiposTramites'); // Recomiendo mover la constante a un archivo utils, pero por ahora la definiré aquí para simplificar

// Si prefieres mantener la constante en el servicio:
const TRAMITE_TYPES = {
    PRUEBAS_GANADO: {
        nombre: 'Pruebas de Ganado',
        etapas: [
            { orden: 1, nombre: 'Solicitud Recibida' },
            { orden: 2, nombre: 'Programación de Visita' },
            { orden: 3, nombre: 'Toma de Muestras' },
            { orden: 4, nombre: 'Muestras en Laboratorio' },
            { orden: 5, nombre: 'Resultados Disponibles' },
            { orden: 6, nombre: 'Finalizado' }
        ]
    },
    MOVILIZACION: {
        nombre: 'Trámite de Movilización',
        etapas: [
            { orden: 1, nombre: 'Solicitud Recibida' },
            { orden: 2, nombre: 'Revisión Documental' },
            { orden: 3, nombre: 'Inspección Sanitaria' },
            { orden: 4, nombre: 'Aprobación Pendiente' },
            { orden: 5, nombre: 'Guía Emitida' },
            { orden: 6, nombre: 'Finalizado' }
        ]
    },
    EXPORTACION: {
        nombre: 'Trámite de Exportación',
        etapas: [
            { orden: 1, nombre: 'Solicitud Recibida' },
            { orden: 2, nombre: 'Revisión Documental' },
            { orden: 3, nombre: 'Certificaciones Sanitarias' },
            { orden: 4, nombre: 'Inspección Aduanal' },
            { orden: 5, nombre: 'Aprobación SENASA' },
            { orden: 6, nombre: 'Documentación Lista' },
            { orden: 7, nombre: 'Finalizado' }
        ]
    }
};

class TramitesService {
    getTipos() {
        return TRAMITE_TYPES;
    }

    async getAll(filters) {
        let query = db.collection('tramites');
        if (filters.tipo) query = query.where('tipo', '==', filters.tipo);
        if (filters.estado) query = query.where('estado', '==', filters.estado);
        if (filters.usuario_id) query = query.where('usuario_id', '==', filters.usuario_id);

        const snapshot = await query.get();
        return snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
    }

    async getById(id) {
        const doc = await db.collection('tramites').doc(id).get();
        if (!doc.exists) return null;
        return { id: doc.id, ...doc.data() };
    }

    async getSeguimiento(id) {
        const doc = await this.getById(id);
        if (!doc) return null;

        const info = TRAMITE_TYPES[doc.tipo];
        return {
            tramite_id: id,
            numero_tramite: doc.numero_tramite,
            tipo: doc.tipo,
            estado_actual: doc.estado,
            etapa_actual: doc.etapa_actual,
            historial: doc.historial || [],
            proxima_etapa: info ? info.etapas.find(e => e.orden === doc.etapa_actual + 1) : null
        };
    }

    async create(data) {
        if (!TRAMITE_TYPES[data.tipo]) throw new Error('Tipo de trámite no válido');

        const nuevoTramite = {
            numero_tramite: `TRM-2026-${String(Math.floor(Math.random() * 1000)).padStart(3, '0')}`,
            tipo: data.tipo,
            usuario_id: data.usuario_id,
            ganado_ids: data.ganado_ids || [],
            fecha_solicitud: new Date().toISOString(),
            etapa_actual: 1,
            estado: 'PENDIENTE',
            observaciones: data.observaciones || '',
            documentos: data.documentos || [],
            historial: [{
                etapa: 1,
                nombre: 'Solicitud Recibida',
                fecha_inicio: new Date().toISOString(),
                responsable: 'Sistema',
                observaciones: 'Trámite creado'
            }]
        };

        const docRef = await db.collection('tramites').add(nuevoTramite);
        return { id: docRef.id, ...nuevoTramite };
    }

    async avanzarEtapa(id, { responsable, observaciones }) {
        const doc = await this.getById(id);
        if (!doc) throw new Error('Trámite no encontrado');

        const info = TRAMITE_TYPES[doc.tipo];
        if (!info) throw new Error('Tipo de trámite desconocido');

        const nextEtapaNum = doc.etapa_actual + 1;
        if (nextEtapaNum > info.etapas.length) throw new Error('Trámite en última etapa');

        const nextEtapaInfo = info.etapas.find(e => e.orden === nextEtapaNum);

        const newHistoryItem = {
            etapa: nextEtapaNum,
            nombre: nextEtapaInfo.nombre,
            fecha_inicio: new Date().toISOString(),
            responsable: responsable || 'Sistema',
            observaciones: observaciones || ''
        };

        await db.collection('tramites').doc(id).update({
            etapa_actual: nextEtapaNum,
            historial: admin.firestore.FieldValue.arrayUnion(newHistoryItem),
            estado: nextEtapaNum === info.etapas.length ? 'COMPLETADO' : 'EN_PROCESO'
        });

        return { etapa_anterior: doc.etapa_actual, etapa_actual: nextEtapaNum, nuevo_historial: newHistoryItem };
    }

    async updateEtapa(id, { etapa, responsable, observaciones }) {
        const doc = await this.getById(id);
        if (!doc) throw new Error('Trámite no encontrado');

        const info = TRAMITE_TYPES[doc.tipo];
        if (etapa < 1 || etapa > info.etapas.length) throw new Error('Etapa inválida');

        const etapaInfo = info.etapas.find(e => e.orden === etapa);
        const historyUpdate = {
            etapa,
            nombre: etapaInfo.nombre,
            fecha_actualizacion: new Date().toISOString(),
            responsable: responsable || 'Admin',
            observaciones: observaciones || 'Manual update'
        };

        await db.collection('tramites').doc(id).update({
            etapa_actual: etapa,
            historial: admin.firestore.FieldValue.arrayUnion(historyUpdate)
        });

        return { etapa_actual: etapa, responsable, observaciones };
    }

    async updateEstado(id, { estado, motivo }) {
        const historyItem = {
            tipo: 'CAMBIO_ESTADO',
            nuevo_estado: estado,
            motivo: motivo || '',
            fecha: new Date().toISOString()
        };
        await db.collection('tramites').doc(id).update({
            estado,
            historial: admin.firestore.FieldValue.arrayUnion(historyItem)
        });
        return { nuevo_estado: estado };
    }

    async addObservacion(id, { observacion, usuario }) {
        const newObs = { observacion, usuario, fecha: new Date().toISOString() };
        await db.collection('tramites').doc(id).update({
            observaciones_list: admin.firestore.FieldValue.arrayUnion(newObs)
        });
        return newObs;
    }

    async addDocumento(id, { nombre_documento, tipo_documento, url }) {
        const newDoc = { nombre: nombre_documento, tipo: tipo_documento, url, fecha_subida: new Date().toISOString() };
        await db.collection('tramites').doc(id).update({
            documentos: admin.firestore.FieldValue.arrayUnion(newDoc)
        });
        return newDoc;
    }

    async cancel(id, { motivo }) {
        return this.updateEstado(id, { estado: 'CANCELADO', motivo: motivo || 'Cancelación usuario' });
    }

    async getStats() {
        const snapshot = await db.collection('tramites').get();
        const stats = { total_tramites: snapshot.size, por_tipo: {}, por_estado: {} };
        snapshot.forEach(doc => {
            const d = doc.data();
            stats.por_tipo[d.tipo] = (stats.por_tipo[d.tipo] || 0) + 1;
            stats.por_estado[d.estado] = (stats.por_estado[d.estado] || 0) + 1;
        });
        return stats;
    }
}

module.exports = new TramitesService();
