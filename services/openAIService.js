const { createAzureClient } = require('../config/azureConfig.js');
const { db, admin } = require('../config/firebaseConfig.js');

const tramitesService = require('./tramitesService.js');

const tools = [
    {
        type: "function",
        function: {
            name: "obtenerTiposTramites",
            description: "Obtiene los requisitos y etapas de los trámites: Pruebas de Ganado, Movilización y Exportación.",
            parameters: { type: "object", properties: {} }
        }
    },
    {
        type: "function",
        function: {
            name: "consultarTramite",
            description: "Consulta el estado y etapa actual de un trámite (Movilización, Exportación o Pruebas).",
            parameters: {
                type: "object",
                properties: {
                    tramite_id: { type: "string", description: "ID del trámite (ej: TRM-2026-001)" }
                },
                required: ["tramite_id"]
            }
        }
    },
    {
        type: "function",
        function: {
            name: "crearTramite",
            description: "Inicia un nuevo proceso de Movilización, Exportación o Pruebas Sanitarias.",
            parameters: {
                type: "object",
                properties: {
                    tipo: { type: "string", enum: ["PRUEBAS_GANADO", "MOVILIZACION", "EXPORTACION"] },
                    uppId: { type: "string", description: "Clave UPP de 12 dígitos" },
                    observaciones: { type: "string" }
                },
                required: ["tipo", "uppId"]
            }
        }
    },
    {
        type: "function",
        function: {
            name: "consultarEstatusSanitario",
            description: "Verifica si la UPP tiene las pruebas de sanidad vigentes (requisito para movilizar/exportar).",
            parameters: {
                type: "object",
                properties: {
                    uppId: { type: "string", description: "Clave de 12 dígitos de la UPP" }
                },
                required: ["uppId"]
            }
        }
    }
];

class OpenAIService {
    constructor() {
        this.client = createAzureClient();
    }

    async getSessionHistory(sesion_id) {
        if (!sesion_id) return [this.getSystemContext()];

        const docRef = db.collection('sesiones').doc(sesion_id);
        const doc = await docRef.get();

        if (!doc.exists) {
            const systemContext = this.getSystemContext();
            // Inicializamos con set
            await docRef.set({
                fecha_inicio: admin.firestore.FieldValue.serverTimestamp(),
                mensajes: [systemContext]
            });
            return [systemContext];
        }

        const data = doc.data();
        return data.mensajes || [this.getSystemContext()];
    }

    getSystemContext() {
        return {
            role: "system",
            content: `## 🐮 Experto en Trámites Ganaderos - UPP & PGN 🐮
            OBJETIVO: Eres un asistente especializado ÚNICAMENTE en la gestión de trámites (Pruebas, Movilización, Exportación). 
            Siempre solicita la Clave UPP de 12 dígitos. Prioriza la Digitalización para reducir archivos físicos.`
        };
    }

    async completion(sesion_id, userMessageContent, ws) {
        // Obtenemos historial DB (async)
        // Usar try/catch para manejar errores de DB
        let history;
        try {
            history = await this.getSessionHistory(sesion_id);
        } catch (e) {
            console.error("Error obteniendo historial:", e);
            history = [this.getSystemContext()];
        }

        // Evitamos duplicar el mensaje si es una re-entrada por función
        if (userMessageContent !== "_FUNCTION_RESULT_") {
            const userMsg = { role: 'user', content: userMessageContent };
            history.push(userMsg);

            if (sesion_id) {
                // CAMBIO: usamos set con merge en lugar de update
                await db.collection('sesiones').doc(sesion_id).set({
                    mensajes: admin.firestore.FieldValue.arrayUnion(userMsg)
                }, { merge: true }).catch(e => console.error("Error guardando user msg:", e));
            }
        }

        let aiResponseContent = "";
        let tempToolCalls = [];

        try {
            const stream = await this.client.chat.completions.create({
                messages: history,
                max_tokens: 1500,
                temperature: 0.2,
                model: process.env.AZURE_OPENAI_DEPLOYMENT_NAME,
                tools: tools,
                stream: true
            });

            for await (const chunk of stream) {
                const delta = chunk.choices[0]?.delta;

                // 1. Manejo de Texto
                if (delta?.content) {
                    const content = delta.content;
                    aiResponseContent += content;
                    // Log enviado a través del socket destinado
                    this.emitEvent(ws, 'ai_chunk', { chunk: content });
                }

                // 2. Manejo de Herramientas (Acumulación)
                if (delta?.tool_calls) {
                    for (const toolCallDelta of delta.tool_calls) {
                        const index = toolCallDelta.index;
                        if (!tempToolCalls[index]) {
                            tempToolCalls[index] = {
                                id: toolCallDelta.id,
                                type: "function",
                                function: { name: "", arguments: "" }
                            };
                        }
                        if (toolCallDelta.function?.name) tempToolCalls[index].function.name += toolCallDelta.function.name;
                        if (toolCallDelta.function?.arguments) tempToolCalls[index].function.arguments += toolCallDelta.function.arguments;
                    }
                }
            }

            // Guardar respuesta de texto si existe
            if (aiResponseContent) {
                const assistantMsg = { role: 'assistant', content: aiResponseContent };
                history.push(assistantMsg);

                if (sesion_id) {
                    // CAMBIO: usamos set con merge
                    await db.collection('sesiones').doc(sesion_id).set({
                        mensajes: admin.firestore.FieldValue.arrayUnion(assistantMsg)
                    }, { merge: true }).catch(e => console.error("Error guardando AI msg:", e));
                }
                this.emitEvent(ws, 'ai_end', { fullResponse: aiResponseContent });
            }
            // 3. Ejecución de Funciones
            if (tempToolCalls.length > 0) {
                history.push({ role: "assistant", tool_calls: tempToolCalls });

                if (sesion_id) {
                    await db.collection('sesiones').doc(sesion_id).update({ mensajes: history });
                }

                for (const tool of tempToolCalls) {
                    const functionName = tool.function.name;
                    const args = JSON.parse(tool.function.arguments);

                    this.emitEvent(ws, 'ai_log', { message: `Consultando base de datos: ${functionName}` });

                    // LLAMADA AL DESPACHADOR CONECTADO AL SERVICIO REAL
                    const result = await this.handleFunctionCall(functionName, args);

                    const toolMsg = {
                        role: "tool",
                        tool_call_id: tool.id,
                        name: functionName,
                        content: JSON.stringify(result)
                    };
                    history.push(toolMsg);

                    if (sesion_id) {
                        await db.collection('sesiones').doc(sesion_id).update({
                            mensajes: admin.firestore.FieldValue.arrayUnion(toolMsg)
                        });
                    }
                }

                return this.completion(sesion_id, "_FUNCTION_RESULT_", ws);
            }

        } catch (error) {
            console.error("Error en completion:", error);
            this.emitEvent(ws, 'remote_error', { details: error.message });
        }
    }

    async handleFunctionCall(name, args) {
        try {
            switch (name) {
                case "obtenerTiposTramites":
                    // Usamos la constante del servicio
                    return tramitesService.getTipos();

                case "consultarTramite":
                    // Buscamos el trámite real en Firebase mediante el ID
                    const tramite = await tramitesService.getSeguimiento(args.tramite_id);
                    return tramite || { error: "Trámite no encontrado" };

                case "crearTramite":
                    // Creamos un trámite real en la colección de trámites
                    // Nota: Aquí podrías necesitar el usuario_id real, si no viene en args
                    // puedes pasarlo desde la sesión.
                    const nuevoTramite = await tramitesService.create({
                        tipo: args.tipo,
                        uppId: args.uppId,
                        usuario_id: "SISTEMA_CHATBOT", // O el ID real del usuario
                        observaciones: args.observaciones
                    });
                    return nuevoTramite;

                case "consultarEstatusSanitario":
                    // Aquí podrías filtrar trámites de tipo PRUEBAS_GANADO para esa UPP
                    // Para simplificar, consultamos si existen trámites completados de sanidad
                    const pruebas = await tramitesService.getAll({
                        tipo: 'PRUEBAS_GANADO',
                        estado: 'COMPLETADO'
                        // Podrías filtrar por uppId si tuvieras ese campo en la base
                    });
                    return {
                        upp: args.uppId,
                        vigente: pruebas.length > 0,
                        total_pruebas: pruebas.length
                    };

                default:
                    return { error: "Función no implementada" };
            }
        } catch (error) {
            console.error(`Error ejecutando ${name}:`, error);
            return { error: error.message };
        }
    }

    emitEvent(ws, event, data) {
        const payload = JSON.stringify({ event, ...data });
        // Priorizamos ws.send para asegurar que el cliente de socket reciba el JSON plano
        if (ws && ws.send) {
            // Verificar estado si es posible, o intentar enviar
            if (ws.readyState === 1 || ws.readyState === undefined) {
                try { ws.send(payload); } catch (e) { console.error("Error enviando WS:", e); }
            }
        } else if (ws && ws.emit) {
            ws.emit(event, data);
        }
    }
}

module.exports = new OpenAIService();