const { createAzureClient } = require('../config/azureConfig.js');

class OpenAIService {
    sessions = new Map();

    constructor() {
        console.log('🔑 Configurando Azure OpenAI (Modo Texto Plano)...');
        this.client = createAzureClient();
    }

    getSystemContext() {
        return {
            role: "system",
            content: `
        ## 🐮 Asistente Virtual de Trámites Ganaderos - PGN 🐮

        **OBJETIVO:** Orientar a productores sobre trámites de la UPP (Unidad de Producción Pecuaria), específicamente en Sanidad (pruebas de enfermedades), Movilización y Exportación.

        **REQUISITOS:** Clave UPP de 12 dígitos, actualización anual y digitalización de documentos para reducir archivos físicos.

        **FORMATO DE RESPUESTA ESTRICTO:** Responde ÚNICAMENTE en JSON:
        {
            "probabilidad_falsa": 0.0,
            "urgencia": "Medio",
            "tipo_incidente_principal": "Sanidad/Pruebas",
            "recursos_despacho": ["SINIIGA"],
            "proxima_pregunta_agente": "Pregunta aquí...",
            "analisis_completo": { ... },
            "razonamiento_justificacion": "Explicación breve..."
        }`
        };
    }

    getSessionHistory(callSid) {
        if (!this.sessions.has(callSid)) {
            this.sessions.set(callSid, [this.getSystemContext()]);
        }
        return this.sessions.get(callSid);
    }

    resetHistory(callSid) {
        if (this.sessions.has(callSid)) {
            this.sessions.delete(callSid);
        }
    }

    /**
     * Versión modificada para Texto Plano (No Streaming)
     */
    async completion(callSid, userMessageContent, emotionContent, ws) {
        console.log(`[IA Service] Iniciando respuesta plana. CallSid: ${callSid}`);

        const history = this.getSessionHistory(callSid);
        history.push({ role: 'user', content: userMessageContent });
        history.push({ role: 'user', content: `Emoción detectada: ${emotionContent}` });

        try {
            // Llamada única a la API (sin stream: true)
            const response = await this.client.chat.completions.create({
                messages: history,
                max_tokens: 2000, // Ajustado para respuestas JSON
                temperature: 0.3,  // Menor temperatura = mayor adherencia al JSON
                model: process.env.AZURE_OPENAI_DEPLOYMENT_NAME,
                stream: false 
            });

            const aiResponseContent = response.choices[0]?.message?.content || "";

            // 1. Guardar en historial
            if (aiResponseContent) {
                history.push({ role: 'assistant', content: aiResponseContent });
            }

            // 2. Enviar respuesta completa de una sola vez
            const payload = {
                event: 'ai_response',
                fullResponse: aiResponseContent,
                historyCount: history.length
            };

            if (ws.emit) {
                ws.emit('ai_response', payload);
            } else if (ws.send) {
                ws.send(JSON.stringify(payload));
            }

            console.log(`[IA Service] Respuesta enviada con éxito.`);

        } catch (error) {
            console.error('❌ Error en Azure OpenAI (Plano):', error);
            const errorMsg = {
                event: 'remote_error',
                message: 'Error al procesar la solicitud',
                details: error.message
            };
            
            if (ws.emit) ws.emit('remote_error', errorMsg);
            else if (ws.send) ws.send(JSON.stringify(errorMsg));
        }
    }
}

module.exports = new OpenAIService();