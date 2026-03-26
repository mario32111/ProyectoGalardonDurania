const { db } = require('../config/firebaseConfig');
const TramitesService = require('./tramitesService'); // Importar TramitesService

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

    async getTramiteStatus(filters) {
        try {
            let tramite = null;

            // Prioritize getting by ID if provided
            if (filters.tramiteId) {
                tramite = await TramitesService.getById(filters.tramiteId);
                if (!tramite) {
                    return { success: false, message: `Trámite con ID ${filters.tramiteId} no encontrado.` };
                }
            } else if (filters.upp && filters.nombreTramite) {
                // If no ID, try to find by upp and nombreTramite (tipo)
                // Assuming 'upp' is a field in the 'tramites' collection. If not, this filter needs adjustment.
                const queryFilters = {
                    upp: filters.upp, 
                    tipo: filters.nombreTramite 
                };
                
                const tramites = await TramitesService.getAll(queryFilters);

                if (tramites.length === 0) {
                    return { success: false, message: `No se encontraron trámites con UP P: ${filters.upp} y tipo: ${filters.nombreTramite}.` };
                }
                
                // If multiple found, return the most recent one by sorting by fecha_solicitud.
                if (tramites.length > 1) {
                    tramites.sort((a, b) => new Date(b.fecha_solicitud) - new Date(a.fecha_solicitud));
                    tramite = tramites[0]; 
                    console.warn(`Multiple trámites found for UP P: ${filters.upp} and type: ${filters.nombreTramite}. Returning the most recent one.`);
                } else {
                    tramite = tramites[0];
                }
            } else {
                return { success: false, message: "Se requiere el ID del trámite, o la UP P y el nombre/tipo de trámite para obtener el estado." };
            }

            // If a tramite was found, format its status similar to getSeguimiento
            if (tramite) {
                // Get tipo info from TramiteTypes, assuming TRAMITE_TYPES is accessible or can be fetched.
                // For now, directly accessing TRAMITE_TYPES from TramitesService might require importing it here
                // or modifying TramitesService to expose getTipos() or TRAMITE_TYPES
                const tramitesTypes = TramitesService.getTipos(); // Assuming getTipos() is available
                const info = tramitesTypes ? tramitesTypes[tramite.tipo] : null;
                
                return {
                    success: true,
                    data: {
                        tramite_id: tramite.id,
                        numero_tramite: tramite.numero_tramite,
                        tipo: tramite.tipo,
                        estado_actual: tramite.estado,
                        etapa_actual: tramite.etapa_actual,
                        historial: tramite.historial || [],
                        proxima_etapa: info ? info.etapas.find(e => e.orden === tramite.etapa_actual + 1) : null,
                        observaciones_list: tramite.observaciones_list || [] // Include observations if available
                    }
                };
            } else {
                return { success: false, message: "No se pudo obtener la información del trámite." };
            }

        } catch (error) {
            console.error('Error getting tramite status:', error);
            return { success: false, message: `Error interno al obtener el estado del trámite: ${error.message}` };
        }
    }
}

module.exports = new ChatbotService();
