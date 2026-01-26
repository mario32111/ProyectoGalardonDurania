const WebSocket = require('ws');
const openAIService = require('../services/openAIService'); // Ajusta la ruta

const wss = new WebSocket.Server({ port: 8080 });

// Listener global del servidor para eventos emitidos cuando se usa vía HTTP
wss.on('ai_chunk', (message) => console.log('📡 [Server Event] Mapeo de chunk recibido:', message));
wss.on('ai_end', (fullResponse) => console.log('📡 [Server Event] Respuesta completa recibida:', fullResponse));

wss.on('connection', (ws) => {
    console.log('📱 Cliente conectado al bot ganadero');

    ws.on('message', async (message) => {
        try {
            const data = JSON.parse(message);

            // Asumimos que el cliente envía: { callSid: "123", userMessage: "Hola" }
            const { callSid, userMessage } = data;

            if (userMessage) {
                // LLAMADA AL SERVICIO QUE CREASTE
                await openAIService.completion(callSid, userMessage, ws);
            }
        } catch (error) {
            console.error('Error procesando mensaje:', error);
        }
    });


    ws.on('close', () => console.log('❌ Cliente desconectado'));
});

module.exports = wss;