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

    async completion(callSid, userMessageContent, ws) {
        console.log(`[IA Service] Iniciando streaming. CallSid: ${callSid}`);

        const history = this.getSessionHistory(callSid);
        history.push({ role: 'user', content: userMessageContent });

        let aiResponseContent = "";

        try {
            const stream = await this.client.chat.completions.create({
                messages: history,
                max_tokens: 2000,
                temperature: 0.3,
                model: process.env.AZURE_OPENAI_DEPLOYMENT_NAME,
                stream: true // <--- ACTIVAMOS EL STREAMING
            });

            for await (const chunk of stream) {
                const content = chunk.choices[0]?.delta?.content || "";
                if (content) {
                    aiResponseContent += content;

                    // Enviamos cada pedacito al cliente inmediatamente
                    const payload = {
                        event: 'ai_chunk',
                        chunk: content
                    };

                    if (ws.emit) {
                        ws.emit('ai_chunk', payload);
                    } else if (ws.send) {
                        ws.send(JSON.stringify(payload));
                    }
                }
            }

            // Al terminar el stream, guardamos la respuesta completa en el historial
            history.push({ role: 'assistant', content: aiResponseContent });

            // Notificamos que el stream terminó
            const endPayload = { event: 'ai_end' };
            if (ws.emit) ws.emit('ai_end', endPayload);
            else if (ws.send) ws.send(JSON.stringify(endPayload));

            console.log(`[IA Service] Stream finalizado con éxito.`);

        } catch (error) {
            console.error('❌ Error en streaming:', error);
            // Manejo de errores omitido por brevedad...
        }
    }
}

module.exports = new OpenAIService();