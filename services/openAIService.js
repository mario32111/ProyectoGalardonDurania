
const { createAzureClient } = require('../config/azureConfig.js');

class OpenAIService {
    sessions = new Map();

    constructor() {
        console.log('🔑 Configurando Azure OpenAI...');
        this.client = createAzureClient();
    }


    // Método para obtener el contexto del sistema (separado para mantener el constructor limpio)
getSystemContext() {
        return {
            role: "system",
            content: `
        ## 🐮 Asistente Virtual de Trámites Ganaderos - Sistema de Identificación 🐮

        **OBJETIVO:** Actuar como un chatbot experto para orientar a los productores del Estado en los trámites de la Unidad de Producción Pecuaria (UPP). Tu enfoque principal son los procesos de sanidad (pruebas de enfermedades), movilización y exportación de ganado.

        **CONTEXTO OPERATIVO (Basado en PGN):**
        1. **Registro UPP:** Cada productor debe estar en el Padrón Ganadero Nacional (PGN) con una clave de 12 dígitos.
        2. **Actualización:** Las UPP deben actualizarse al menos una vez al año (existen aproximadamente 45,000 UPPs).
        3. **Documentación:** Se requiere digitalizar documentos del productor, del predio y, crucialmente, de sanidad de los bovinos.

        **SERVICIOS ESPECÍFICOS A ASISTIR:**
        - **Pruebas de Ganado (Sanidad):** Orientar sobre la carga de resultados de pruebas para asegurar que el ganado esté libre de enfermedades.
        - **Movilización:** Requisitos para el traslado de animales entre zonas o UPPs.
        - **Exportación:** Trámites necesarios para la salida de ganado del estado o país, vinculados al estatus sanitario de la UPP.

        **FORMATO DE RESPUESTA ESTRICTO:**
        Debes responder **SIEMPRE** en un único objeto JSON. No incluyas texto explicativo fuera del JSON.

        {
            "probabilidad_falsa": 0.0, // Solo si detectas una consulta incoherente (0.0 a 1.0)
            "urgencia": "Medio", // "Bajo", "Medio", o "Alto" según el trámite o problema reportado
            "tipo_incidente_principal": "Trámite de Sanidad", // Categorías: "Sanidad/Pruebas", "Movilización", "Exportación", "Actualización UPP"
            "recursos_despacho": ["SINIIGA", "Ventanilla UPP"], // Entidades o departamentos involucrados
            "proxima_pregunta_agente": "¿Cuenta con su clave UPP de 12 dígitos para verificar el estatus de sus pruebas de sanidad?", // Pregunta clave para avanzar
            "analisis_completo": {
                "falsa_probabilidad": 0.0,
                "urgencia_probabilidad": { "Bajo": 0.7, "Medio": 0.2, "Alto": 0.1 },
                "incidentes_probabilidad": {
                    "Sanidad/Pruebas": 1.0,
                    "Movilización": 0.0,
                    "Exportación": 0.0,
                    "Otros": 0.0
                }
            },
            "razonamiento_justificacion": "El productor solicita información sobre cómo subir los resultados de las pruebas de brucelosis. Se le guía hacia la digitalización de documentos requerida por el sistema de consulta de documentación de la UPP."
        }

        **INSTRUCCIÓN FINAL:** Tu tono debe ser profesional y servicial. Prioriza la reducción de archivos físicos mediante la invitación a subir archivos digitales relacionados a la sanidad y propiedad del predio.
        `
        };
    }

    // Método para obtener el historial de una sesión específica
    getSessionHistory(callSid) {
        if (!this.sessions.has(callSid)) {
            this.sessions.set(callSid, [this.getSystemContext()]);
        }
        return this.sessions.get(callSid);
    }

    // Método para resetear la conversación de una llamada específica
    resetHistory(callSid) {
        if (this.sessions.has(callSid)) {
            this.sessions.delete(callSid);
        }
    }

    async streamingCompletion(callSid, userMessageContent, emotionContent, ws) {
        console.log(`[IA Service] Iniciando stream para socket. CallSid: ${callSid}`);

        const history = this.getSessionHistory(callSid);
        history.push({ role: 'user', content: userMessageContent });
        history.push({ role: 'user', content: `Emoción detectada: ${emotionContent}` });



        const finalMessages = history;
        const defaultOptions = {
            max_tokens: 4096,
            temperature: 0.7,
            model: process.env.AZURE_OPENAI_DEPLOYMENT_NAME,
            stream: true,
        };
        let aiResponseContent = "";

        try {
            const stream = await this.client.chat.completions.create({
                messages: finalMessages, // Usa el historial completo
                ...defaultOptions
            });

            // Iteramos sobre el stream de Azure
            for await (const chunk of stream) {
                const content = chunk.choices[0]?.delta?.content || "";
                if (content) {
                    aiResponseContent += content; // Acumulamos el chunk

                    // --- CALLBACK: ai_chunk ---
                    if (ws.emit) {
                        ws.emit('ai_chunk', { chunk: content });
                    } else if (ws.send) {
                        ws.send(JSON.stringify({ event: 'ai_chunk', chunk: content }));
                    }
                }
            }

            // 4. Agregamos la respuesta completa de la IA al historial
            if (aiResponseContent.length > 0) {
                history.push({ role: 'assistant', content: aiResponseContent });
            }


            console.log(`[IA Service] Stream finalizado. Historial con ${history.length} mensajes.`);
            if (ws.emit) {
                ws.emit('ai_end', { fullResponse: "Stream finalizado." });
            } else if (ws.send) {
                ws.send(JSON.stringify({ event: 'ai_end', fullResponse: "Stream finalizado." }));
            }

        } catch (error) {
            console.error('❌ Error en streaming Azure OpenAI:', error);
            // --- CALLBACK: remote_error ---
            const errorMsg = {
                message: 'Error durante el stream con Azure OpenAI',
                details: error.message
            };
            if (ws.emit) {
                ws.emit('remote_error', errorMsg);
            } else if (ws.send) {
                ws.send(JSON.stringify({ event: 'remote_error', ...errorMsg }));
            }
        }
    }
}

module.exports = new OpenAIService();
