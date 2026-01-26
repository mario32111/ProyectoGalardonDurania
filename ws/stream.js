const WebSocket = require('ws');
const openAIService = require('./services/OpenAIService'); // Ajusta la ruta

const wss = new WebSocket.Server({ port: 8080 });

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