const path = require('path');
const transcribeService = require('../services/transcribeService');
const emotionService = require('../services/emotionService');
const iaService = require('../services/openAIService');
const { saveWavFile, RECORDINGS_DIR } = require('../services/audioService');
const config = require('../config');
const client = require('twilio')(config.twilioAccountSid, config.twilioAuthToken);
const { VoiceResponse } = require('twilio').twiml;

let fullAiResponse = '';
let questionSent = false; // Bandera para asegurar que la pregunta solo se envíe una vez.

module.exports = (app) => {
    app.ws('/stream', (ws, req) => {
        console.log('¡Conexión de WebSocket /stream establecida!');
        let streamBuffer = Buffer.alloc(0);
        const CHUNK_SIZE_10S = 80000;
        const CHUNK_SIZE_30S = 240000;
        let callSid = 'unknown_call';
        let processedBytes = 0;
        let chunkCounter = 1;
        let saved30s = false;

        ws.on('message', async (msg) => {
            try {
                const twilioMsg = JSON.parse(msg);
                switch (twilioMsg.event) {
                    case 'start':
                        console.log('Evento "start": La llamada ha comenzado.');
                        callSid = twilioMsg.start.callSid;
                        // Restablecemos las variables de estado al inicio de un nuevo stream
                        fullAiResponse = '';
                        questionSent = false;
                        break;
                    case 'media':
                        const audioChunk = Buffer.from(twilioMsg.media.payload, 'base64');
                        streamBuffer = Buffer.concat([streamBuffer, audioChunk]);

                        while ((streamBuffer.length - processedBytes) >= CHUNK_SIZE_10S) {
                            const endByte = processedBytes + CHUNK_SIZE_10S;
                            const chunk10s = streamBuffer.slice(processedBytes, endByte);
                            const filename = `${callSid}_part_${chunkCounter}.wav`;
                            const filePath = path.join(RECORDINGS_DIR, filename);
                            saveWavFile(chunk10s, filePath);
                            console.log(`✅ Guardado segmento ${chunkCounter} de 10s.`);

                            // Actualizamos contadores ANTES del await para evitar condiciones de carrera
                            processedBytes += CHUNK_SIZE_10S;
                            chunkCounter++;

                            // NOTA: Se asume que transcribeService y emotionService ya no tienen lógica de contexto
                            const transcribeResponse = await transcribeService.enviarAudio(filePath);
                            const emotionResponse = await emotionService.enviarAudio(filePath);
                            
                            const userMessageContent = transcribeResponse.texto || 'No se detectó habla.';
                            // Se asume que emotionService devuelve el campo 'emocion'
                            const emotionContent = emotionResponse.emocion || 'neutral'; 

                            // Enviamos al servicio de IA para el procesamiento en streaming
                            iaService.streamingCompletion(callSid, userMessageContent, emotionContent, ws);
                        }
                        
                        // Lógica de guardado de clip de 30s (sin cambios)
                        if (!saved30s && streamBuffer.length >= CHUNK_SIZE_30S) {
                            saved30s = true;

                            const chunk30s = streamBuffer.slice(0, CHUNK_SIZE_30S);
                            const filename30 = `${callSid}_FIRST_30s.wav`;
                            const filePath30 = path.join(RECORDINGS_DIR, filename30);
                            saveWavFile(chunk30s, filePath30);
                            console.log('🌟 Clip acumulado de 30 segundos guardado.');
                        }
                        break;
                    case 'stop':
                        console.log('Evento "stop": La llamada ha terminado.');
                        transcribeService.resetContext();
                        // iaService.resetHistory(callSid); // 🚨 Comentado para mantener el contexto entre streams (TwiML updates).
                        break;
                }
            } catch (error) {
                console.error('Error procesando el mensaje de WebSocket:', error);
            }
        });

        ws.on('ai_chunk', (data) => {
            const chunkContent = data.chunk;

            // 1. Acumulamos el contenido del chunk
            fullAiResponse += chunkContent;

            // 2. Si la pregunta aún no se ha enviado, intentamos detectarla.
            if (!questionSent) {
                try {
                    // Intentamos parsear el JSON completo acumulado hasta ahora para detectar la pregunta.
                    const partialJson = JSON.parse(fullAiResponse);

                    // 3. Verificamos si el campo de la pregunta existe en el objeto parseado.
                    if (partialJson.proxima_pregunta_agente) {
                        const question = partialJson.proxima_pregunta_agente;

                        console.log(`[Agente Talk] 💬 Pregunta Crítica Detectada: "${question}"`);
                        
                        // 4. Interrumpimos la llamada para que Twilio hable.
                        console.log(`[Agente Talk] 🗣️ Hablando: "${question}"`);

                        const twiml = new VoiceResponse();
                        twiml.say({
                            voice: 'es-MX-Standard-A',
                            language: 'es-MX'
                        }, question);

                        // Reconectamos el stream para escuchar la respuesta del usuario
                        const connect = twiml.connect();
                        connect.stream({
                            url: `wss://${config.wsUrl}/stream`,
                            track: 'inbound_track'
                        });

                        client.calls(callSid)
                            .update({
                                twiml: twiml.toString()
                            })
                            .then(call => {
                                console.log('[Agente Talk] ✅ Llamada actualizada con respuesta de voz.');
                                questionSent = true;
                                fullAiResponse = ''; // Limpiamos el buffer si ya enviamos la pregunta
                            })
                            .catch(err => {
                                console.error('[Agente Talk] ❌ Error actualizando llamada:', err);
                            });
                    }
                } catch (error) {
                    // Es normal que falle el JSON.parse hasta que el JSON esté completo. No imprimimos errores aquí.
                }
            }
        });
        
        // --- NUEVA LÓGICA AGREGADA ---
        // Este evento se dispara cuando el servicio de IA termina de enviar la respuesta.
        ws.on('ai_end', () => {
            try {
                const finalJson = JSON.parse(fullAiResponse);
                console.log('--- JSON FINAL DE LA RESPUESTA DE LA IA ---');
                console.log(JSON.stringify(finalJson, null, 2));
                console.log('-------------------------------------------');
            } catch (error) {
                console.error('❌ Error al parsear el JSON completo al finalizar el stream:', error);
            }
            // Después de procesar el JSON final, limpiamos el buffer
            fullAiResponse = ''; 
        });
        // -----------------------------

        ws.on('close', () => {
            console.log('Conexión de WebSocket /stream cerrada.');
            // Limpiamos la bandera y el buffer al cerrar la conexión.
            fullAiResponse = '';
            questionSent = false;
        });
    });
};