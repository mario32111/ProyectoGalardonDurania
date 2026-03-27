const { admin, db } = require('../config/firebaseConfig');

/**
 * Servicio para envío de notificaciones push y persistencia en base de datos.
 */
class NotificationService {
  /**
   * Envía una notificación a un usuario específico y la guarda en su historial.
   * @param {string} usuarioId - ID del usuario en Firestore.
   * @param {Object} payload - Contenido de la notificación.
   * @param {string} payload.titulo - Título de la notificación.
   * @param {string} payload.mensaje - Cuerpo del mensaje.
   * @param {string} [payload.tipo='general'] - Tipo: 'critico', 'advertencia', 'info', 'general'.
   * @param {Object} [payload.data={}] - Datos adicionales para el payload FCM.
   */
  async sendToUser(usuarioId, payload) {
    const { titulo, mensaje, tipo = 'general', data = {} } = payload;

    try {
      // 1. Guardar en el historial de notificaciones (Firestore)
      const notificacionRef = await db.collection('notificaciones').add({
        usuario_id: usuarioId,
        titulo,
        mensaje,
        tipo,
        leido: false,
        fecha: new Date().toISOString()
      });

      // 2. Obtener los tokens FCM del usuario
      const userDoc = await db.collection('usuarios').doc(usuarioId).get();
      if (!userDoc.exists) {
        console.warn(`⚠️ Usuario ${usuarioId} no encontrado al intentar enviar notificación.`);
        return { success: false, message: 'Usuario no encontrado' };
      }

      const { fcmTokens } = userDoc.data();
      if (!fcmTokens || !Array.isArray(fcmTokens) || fcmTokens.length === 0) {
        console.log(`ℹ️ Usuario ${usuarioId} no tiene tokens registrados. Solo se guardó en el historial.`);
        return { success: true, persistedId: notificacionRef.id, sent: false };
      }

      // 3. Preparar el mensaje FCM
      // Mapeo para Android nativo (Background)
      let icon = 'ic_stat_default';
      let color = '#01579B'; // Azul default
      
      if (tipo === 'critico') {
        icon = 'ic_stat_critico';
        color = '#F44336'; // Rojo
      } else if (tipo === 'advertencia') {
        icon = 'ic_stat_warning';
        color = '#FF9800'; // Naranja
      } else if (tipo === 'info') {
        icon = 'ic_stat_info';
        color = '#4CAF50'; // Verde
      }

      const message = {
        notification: {
          title: titulo,
          body: mensaje,
        },
        android: {
          notification: {
            icon: icon,
            color: color,
            channelId: 'high_importance_channel', // Coincidir con el canal en Flutter
          }
        },
        data: {
          ...data,
          tipo: tipo,
          id: notificacionRef.id,
          click_action: 'FLUTTER_NOTIFICATION_CLICK'
        },
        tokens: fcmTokens,
      };

      // 4. Enviar vía Firebase Admin SDK
      const response = await admin.messaging().sendEachForMulticast(message);
      
      console.log(`✅ Notificaciones enviadas: ${response.successCount} exitosas, ${response.failureCount} fallidas.`);

      // Limpieza de tokens inválidos (opcional pero recomendado)
      if (response.failureCount > 0) {
        this._cleanupTokens(usuarioId, fcmTokens, response.responses);
      }

      return {
        success: true,
        persistedId: notificacionRef.id,
        sent: true,
        successCount: response.successCount
      };
    } catch (error) {
      console.error('❌ Error en NotificationService.sendToUser:', error);
      throw error;
    }
  }

  /**
   * Limpia tokens que ya no son válidos (expirados o desinstalados).
   */
  async _cleanupTokens(usuarioId, tokens, responses) {
    const tokensToRemove = [];
    responses.forEach((resp, idx) => {
      if (!resp.success) {
        const errorCode = resp.error.code;
        if (errorCode === 'messaging/invalid-registration-token' ||
            errorCode === 'messaging/registration-token-not-registered') {
          tokensToRemove.push(tokens[idx]);
        }
      }
    });

    if (tokensToRemove.length > 0) {
      const userRef = db.collection('usuarios').doc(usuarioId);
      await userRef.update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove)
      });
      console.log(`🧹 Limpieza: Se eliminaron ${tokensToRemove.length} tokens inválidos del usuario ${usuarioId}.`);
    }
  }
}

module.exports = new NotificationService();
