const { db } = require('../config/firebaseConfig');
const TramitesService = require('./tramitesService'); // Importar TramitesService

class ChatbotService {
    async getHistorial(usuario_id, limite = 50) {
        // Quitamos temporalmente .orderBy para evitar el Error 500 si falta el índice en Firebase
        const snapshot = await db.collection('sesiones')
            .where('usuario_id', '==', usuario_id)
            .limit(Number(limite))
            .get();
        
        let conversaciones = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        
        // Ordenamos en memoria para no cargar a la base de datos y evitar el error 500
        conversaciones.sort((a, b) => {
            const dateA = new Date(a.fecha_inicio || 0);
            const dateB = new Date(b.fecha_inicio || 0);
            return dateB - dateA;
        });

        return conversaciones;
    }

    async getSesion(sesion_id, usuario_id) {
        const doc = await db.collection('sesiones').doc(sesion_id).get();
        if (!doc.exists) return null;
        const data = doc.data();
        if (data.usuario_id !== usuario_id) return null; // <--- Validación de propiedad
        return { sesion_id: doc.id, ...data };
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

    async deleteSesion(sesion_id, usuario_id) {
        const docRef = db.collection('sesiones').doc(sesion_id);
        const doc = await docRef.get();
        
        if (!doc.exists || doc.data().usuario_id !== usuario_id) {
            throw new Error('No autorizado o sesión no encontrada');
        }

        await docRef.delete();
        return { sesion_id };
    }

    async saveFeedback(data, usuario_id) {
        const feedbackData = {
            ...data,
            usuario_id, // <--- Registrar quién dio el feedback
            fecha: new Date().toISOString()
        };
        await db.collection('feedback_chatbot').add(feedbackData);
        return feedbackData;
    }

    async getTramiteStatus(filters, usuario_id) {
        try {
            let tramite = null;

            // Prioritize getting by ID if provided
            if (filters.tramiteId) {
                tramite = await TramitesService.getById(filters.tramiteId, usuario_id);
                if (!tramite) {
                    return { success: false, message: `Trámite con ID ${filters.tramiteId} no encontrado o no autorizado.` };
                }
            } else if (filters.upp && filters.nombreTramite) {
                // If no ID, try to find by upp and nombreTramite (tipo)
                // Assuming 'upp' is a field in the 'tramites' collection. If not, this filter needs adjustment.
                const queryFilters = {
                    upp: filters.upp, 
                    tipo: filters.nombreTramite 
                };
                
                const tramites = await TramitesService.getAll(queryFilters, usuario_id);

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
