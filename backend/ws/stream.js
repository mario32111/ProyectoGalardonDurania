const WebSocket = require('ws');
const openAIService = require('../services/openAIService');
const speechService = require('../services/speechService');

const wss = new WebSocket.Server({ port: 8080 });

wss.on('connection', (ws) => {
    console.log('📱 Cliente conectado al bot ganadero');

    // Estado de la sesión de audio por conexión
    let audioBuffer = null;   // Buffer acumulador de audio
    let audioActive = false;  // Si estamos grabando
    let audioSessionId = null;
    let autoChat = false;
    let audioFormat = 'wav';

    ws.on('message', async (message) => {
        // Si hay una sesión de audio activa y el mensaje es binario, acumular audio
        if (audioActive && Buffer.isBuffer(message)) {
            if (audioBuffer) {
                audioBuffer = Buffer.concat([audioBuffer, message]);
            } else {
                audioBuffer = message;
            }
            return;
        }

        // Mensajes JSON de control
        try {
            const data = JSON.parse(message);

            // ============================================
            // MODO TEXTO: Chat normal con texto
            // ============================================
            if (data.userMessage) {
                const { callSid, userMessage } = data;
                await openAIService.completion(callSid, userMessage, ws);
                return;
            }

            // ============================================
            // MODO AUDIO: Grabación y transcripción
            // ============================================

            // Iniciar captura de audio
            if (data.action === 'start_audio') {
                audioSessionId = data.session_id || null;
                autoChat = data.autoChat || false;
                audioFormat = data.format || 'wav'; // wav, webm, ogg, mp3
                audioBuffer = null;
                audioActive = true;

                console.log('🎙️ [WS] Captura de audio iniciada, sesión:', audioSessionId);

                ws.send(JSON.stringify({
                    event: 'speech_ready',
                    message: `Envía audio en formato ${audioFormat}. Envía stop_audio para transcribir.`
                }));
                return;
            }

            // Detener captura y transcribir
            if (data.action === 'stop_audio') {
                audioActive = false;
                console.log('🛑 [WS] Captura de audio detenida');

                if (!audioBuffer || audioBuffer.length === 0) {
                    ws.send(JSON.stringify({
                        event: 'speech_error',
                        error: 'No se recibió audio'
                    }));
                    return;
                }

                console.log(`📦 [WS] Audio acumulado: ${(audioBuffer.length / 1024).toFixed(1)}KB`);

                try {
                    // Transcribir el buffer acumulado
                    const result = await speechService.transcribeBuffer(audioBuffer, audioFormat);
                    audioBuffer = null;

                    if (!result.text) {
                        ws.send(JSON.stringify({
                            event: 'speech_error',
                            error: 'No se detectó habla en el audio'
                        }));
                        return;
                    }

                    console.log('📝 [WS] Texto reconocido:', result.text);

                    // Enviar transcripción al cliente
                    if (ws.readyState === WebSocket.OPEN) {
                        ws.send(JSON.stringify({
                            event: 'speech_final',
                            text: result.text,
                            duration: result.duration
                        }));
                    }

                    // Si autoChat, enviar al chatbot automáticamente
                    if (autoChat && result.text) {
                        console.log('🤖 [WS] Enviando texto al chatbot...');
                        await openAIService.completion(audioSessionId, result.text, ws);
                    }
                } catch (error) {
                    console.error('❌ [WS] Error transcribiendo:', error.message);
                    ws.send(JSON.stringify({
                        event: 'speech_error',
                        error: error.message
                    }));
                }

                ws.send(JSON.stringify({
                    event: 'speech_stopped',
                    message: 'Sesión de audio finalizada'
                }));
                return;
            }

            // Enviar un audio completo de una sola vez (sin start/stop)
            if (data.action === 'transcribe_audio' && data.audio) {
                console.log('🎙️ [WS] Audio base64 recibido para transcripción');
                try {
                    const buffer = Buffer.from(data.audio, 'base64');
                    const format = data.format || 'wav';
                    const result = await speechService.transcribeBuffer(buffer, format);

                    ws.send(JSON.stringify({
                        event: 'speech_final',
                        text: result.text,
                        duration: result.duration
                    }));

                    if (data.autoChat && result.text) {
                        const sessionId = data.session_id || null;
                        await openAIService.completion(sessionId, result.text, ws);
                    }
                } catch (error) {
                    ws.send(JSON.stringify({
                        event: 'speech_error',
                        error: error.message
                    }));
                }
                return;
            }

        } catch (error) {
            if (!audioActive) {
                console.error('Error procesando mensaje:', error.message);
            }
        }
    });

    ws.on('close', () => {
        console.log('❌ Cliente desconectado');
        audioBuffer = null;
        audioActive = false;
    });
});

module.exports = wss;