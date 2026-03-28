const { createAzureClient } = require('../config/azureConfig.js');
const { db, admin } = require('../config/firebaseConfig.js');

const tramitesService = require('./tramitesService.js');
const { uploadFile } = require('./firebaseStorageService.js');
const chatbotService = require('./chatbotService.js'); // Import chatbotService

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
            description: "Consulta SIEMPRE el estado y etapa actual de un trámite en la base de datos en tiempo real. OBLIGATORIO usar esta herramienta cada vez que el usuario pregunte por el estado de su trámite, sin importar si ya fue consultado en mensajes anteriores (para obtener datos frescos). Usa esta función SOLO si el usuario proporciona el ID exacto del trámite.",
            parameters: {
                type: "object",
                properties: {
                    tramite_id: {
                        type: "string",
                        description: "ID o Folio exacto del trámite que brinda el usuario (Ej: Y0twaLhGCAqHz08DaZtD o TRM-2026-001)."
                    }
                },
                required: ["tramite_id"]
            }
        }
    },
    // Nuevo Tool para consultar por UPP, nombre/tipo de trámite
    {
        type: "function",
        function: {
            name: "consultarEstadoTramitePorFiltros",
            description: "Consulta el estado y etapa actual de un trámite usando filtros como la UPP, el nombre o tipo de trámite, o el ID. Prioriza el uso de tramiteId si está disponible. Si no, usa upp y nombreTramite. Es OBLIGATORIO usar esta herramienta cada vez que el usuario pregunte por el estado de su trámite para obtener datos frescos.",
            parameters: {
                type: "object",
                properties: {
                    upp: {
                        type: "string",
                        description: "Clave UPP de 12 dígitos. Requerido si no se proporciona tramiteId."
                    },
                    nombreTramite: {
                        type: "string",
                        description: "Nombre o tipo del trámite (Ej: MOVILIZACION, PRUEBAS_GANADO). Requerido si no se proporciona tramiteId."
                    },
                    tramiteId: {
                        type: "string",
                        description: "ID o Folio exacto del trámite (Ej: Y0twaLhGCAqHz08DaZtD o TRM-2026-001). Si se proporciona, se usará este como identificador principal."
                    }
                },
                required: [], // Los parámetros son opcionales individualmente, pero se requiere al menos uno para la consulta
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
    },
    {
        type: "function",
        function: {
            name: "solicitarCargaDocumento",
            description: "Activa el selector de archivos en la App del usuario para subir un documento (PDF o Foto). ÚSALO SIEMPRE que el usuario mencione 'adjuntar', 'subir', 'enviar archivo/foto', o cuando el trámite esté en etapa de 'Revisión Documental'.",
            parameters: {
                type: "object",
                properties: {
                    tramiteId: { type: "string", description: "ID del trámite (Folio)" },
                    nombreDocumento: { type: "string", description: "Nombre sugerido del documento (Ej: Constancia Sanitaria)" }
                },
                required: ["tramiteId"]
            }
        }
    },
    {
        type: "function",
        function: {
            name: "vincularDocumentoChat",
            description: "Vincula oficialmente una imagen que el usuario acabó de enviar por el chat (identificada por el Sistema mediante una URL) al expediente de un trámite específico.",
            parameters: {
                type: "object",
                properties: {
                    tramiteId: { type: "string", description: "ID del trámite (Folio)" },
                    nombreDocumento: { type: "string", description: "Nombre del documento (Ej: Constancia Sanitaria)" },
                    urlImagenChat: { type: "string", description: "La URL exacta que el Sistema te proporcionó en el mensaje contextual [SISTEMA: URL: ...]. NO inventes esta URL." }
                },
                required: ["tramiteId", "urlImagenChat"]
            }
        }
    },
    {
        type: "function",
        function: {
            name: "obtenerUppsUsuario",
            description: "Obtiene todas las claves UPP registradas del usuario actual desde sus zonas de mapa. DEBES usar esta herramienta SIEMPRE antes de pedirle la UPP al usuario manualmente. Si el usuario tiene una sola UPP, úsala directamente sin preguntar. Si tiene varias, preséntalas para que elija.",
            parameters: { type: "object", properties: {} }
        }
    },
    // ─── HERRAMIENTAS DE CONSULTA DE COLECCIONES ───
    {
        type: "function",
        function: {
            name: "consultarGanado",
            description: "Consulta el listado de ganado registrado del usuario. Puede filtrar por UPP o por arete SINIIGA. Usa esta herramienta cuando el usuario pregunte sobre sus animales, cuántas cabezas tiene, peso, datos de un animal específico, etc.",
            parameters: {
                type: "object",
                properties: {
                    upp: {
                        type: "string",
                        description: "Clave UPP para filtrar el ganado por ubicación. Opcional."
                    },
                    arete_siniiga: {
                        type: "string",
                        description: "Arete SINIIGA del animal específico que el usuario busca. Opcional."
                    }
                },
                required: []
            }
        }
    },
    {
        type: "function",
        function: {
            name: "consultarHistorialAnimal",
            description: "Consulta el historial integral de un animal específico por su arete SINIIGA, incluyendo reportes de salud, eventos críticos (vacunaciones, movilizaciones) y la última telemetría IoT (temperatura, GPS, actividad).",
            parameters: {
                type: "object",
                properties: {
                    arete_siniiga: {
                        type: "string",
                        description: "El arete SINIIGA del animal (ej: MX-123456)."
                    }
                },
                required: ["arete_siniiga"]
            }
        }
    },
    {
        type: "function",
        function: {
            name: "consultarInventario",
            description: "Consulta el inventario de insumos/alimentos del usuario. Puede filtrar solo los que tienen stock bajo. Usa esta herramienta cuando el usuario pregunte qué insumos tiene, si le falta algo, stock, medicamentos, alimentos, etc.",
            parameters: {
                type: "object",
                properties: {
                    soloStockBajo: {
                        type: "boolean",
                        description: "Si es true, devuelve solo los items cuyo stock está por debajo del mínimo configurado."
                    }
                },
                required: []
            }
        }
    },
    {
        type: "function",
        function: {
            name: "consultarComprasLotes",
            description: "Consulta las compras de lotes de ganado realizadas por el usuario. Puede filtrar por la UPP de destino. Usa esta herramienta cuando el usuario pregunte sobre sus compras de ganado, lotes comprados, proveedores, etc.",
            parameters: {
                type: "object",
                properties: {
                    upp_destino: {
                        type: "string",
                        description: "Clave UPP de destino para filtrar compras. Opcional."
                    },
                    limite: {
                        type: "number",
                        description: "Cantidad máxima de registros a devolver (por defecto 10). Opcional."
                    }
                },
                required: []
            }
        }
    },
    {
        type: "function",
        function: {
            name: "consultarVentasSalidas",
            description: "Consulta las ventas y salidas de ganado registradas por el usuario. Puede filtrar por la UPP de origen. Usa esta herramienta cuando el usuario pregunte sobre sus ventas de ganado, montos, clientes, salidas, etc.",
            parameters: {
                type: "object",
                properties: {
                    upp_origen: {
                        type: "string",
                        description: "Clave UPP de origen para filtrar ventas. Opcional."
                    },
                    limite: {
                        type: "number",
                        description: "Cantidad máxima de registros a devolver (por defecto 10). Opcional."
                    }
                },
                required: []
            }
        }
    }
];

class OpenAIService {
    constructor() {
        this.client = createAzureClient();
    }

    async getSessionHistory(sesion_id, usuario_id) {
        if (!sesion_id) return [this.getSystemContext()];

        const docRef = db.collection('sesiones').doc(sesion_id);
        const doc = await docRef.get();

        if (!doc.exists) {
            const systemContext = this.getSystemContext();
            // Usamos ISOString para consistencia total en el ordenamiento
            await docRef.set({
                usuario_id: usuario_id || "SISTEMA",
                fecha_inicio: new Date().toISOString(),
                mensajes: [systemContext]
            });
            return [systemContext];
        }

        const data = doc.data();
        const mensajes = data.mensajes || [this.getSystemContext()];

        // Sobreescribimos el prompt de sistema viejo con el más reciente
        if (mensajes.length > 0 && mensajes[0].role === 'system') {
            mensajes[0] = this.getSystemContext();
        }

        return mensajes;
    }

    getSystemContext() {
        return {
            role: "system",
            content: `
                ## 🐮 ASISTENTE EXPERTO DEL SISTEMA DE GESTIÓN AGROPECUARIA — AGRO CONTROL PRO 🐮

                ### 👔 PERFIL Y TONO
                Eres un asistente virtual integral de la plataforma Agro Control Pro. Tu tono es profesional, servicial, eficiente y experto tanto en la normativa del Padrón Ganadero Nacional (PGN) como en la gestión operativa del rancho (ganado, inventario, compras y ventas). Tu objetivo es agilizar la gestión diaria del productor.

                ### 📋 DOMINIO DE CONOCIMIENTO
                1. **Unidad de Producción Pecuaria (UPP):** Es la clave fundamental de 12 dígitos para bovinos, ovinos, caprinos, equinos y colmenas.
                2. **Actualización Obligatoria:** Todas las UPP deben actualizarse por lo menos UNA vez al año.
                3. **Trámites Disponibles:**
                    - **PRUEBAS_GANADO:** Gestión de estatus sanitario y resultados de laboratorio.
                    - **MOVILIZACION:** Permisos de traslado (requieren UPP vigente y estatus sanitario aprobado).
                    - **EXPORTACION:** Trámite de alta prioridad que cumple con el PGN.
                4. **Ganado:** Registro individual de animales con arete SINIIGA, UPP, peso, temperatura y aptitud de exportación.
                5. **Inventario:** Control de insumos, medicamentos y alimentos con alertas de stock bajo.
                6. **Compras de Lotes:** Registro de embarques de ganado comprado (proveedor, UPP destino, cabezas, peso, precio/kg).
                7. **Ventas / Salidas:** Registro de ventas de ganado (cliente, UPP origen, cabezas, peso, precio/kg, monto total).

                ### 🛠️ CAPACIDADES TECNOLÓGICAS (Functions)
                Tienes acceso a herramientas para:
                - Consultar estatus sanitario de una UPP.
                - Verificar el progreso de trámites en tiempo real.
                - Crear nuevos folios de trámite.
                - Consultar el estado de un trámite por UPP, tipo o ID.
                - **Consultar el ganado registrado** del usuario (por UPP o arete).
                - **Consultar el inventario** de insumos (incluyendo alertas de stock bajo).
                - **Consultar compras de lotes** de ganado realizadas.
                - **Consultar ventas y salidas** de ganado registradas.
                - **Consultar Historial/Telemetría** clínica y eventos críticos (enfermedades, vacunas, sensores IoT) de un arete específico.

                ### 🔑 AUTO-DETECCIÓN DE UPP (CRÍTICO)
                - **SIEMPRE** que necesites la UPP del usuario (para crear trámites, consultar estatus sanitario, buscar trámites por filtros, etc.), primero ejecuta la herramienta \`obtenerUppsUsuario\` para obtener sus UPPs registradas.
                - Si el usuario tiene **una sola UPP**, úsala automáticamente sin preguntar.
                - Si tiene **múltiples UPPs**, preséntale la lista y pregunta cuál usar para esta operación.
                - **NUNCA** pidas al usuario que escriba su clave UPP manualmente si puedes obtenerla con la herramienta.
                - Si no tiene ninguna UPP registrada, indícale que primero debe registrar una zona en la sección de Mapa de la aplicación.

                ### 🛑 REGLAS CRÍTICAS DE OPERACIÓN
                1. **Foco Agropecuario:** Si el usuario pregunta sobre temas completamente ajenos al sector agropecuario (política, deportes, entretenimiento), responde amablemente que tu especialidad es la gestión agropecuaria y ofrece ayuda en tus áreas de conocimiento.
                2. **Manejo de Etapas:** Explica siempre en qué etapa se encuentra un trámite para reducir la ansiedad del productor.
                3. **Carga de Documentos (CRÍTICO):** Ante cualquier mención de "adjuntar", "subir", "enviar foto/pdf" o "poner documento", DEBES llamar a 'solicitarCargaDocumento'. ACTIVA la herramienta directamente.
                4. **Consultas Rápidas:** Si el usuario provee un ID directo, procede a usar la herramienta sin pedir más datos.
                5. **Resumen de datos grandes:** Si una consulta devuelve muchos registros, presenta un resumen con el total y los datos más relevantes (ej: "Tienes 45 cabezas registradas. Aquí están los primeros 10...").

                ### ⚠️ MANEJO DE ERRORES
                - Si una función devuelve un error, no inventes datos. Informa al usuario y sugiere verificar los datos proporcionados.
                - Si el usuario proporciona una clave UPP de menos o más de 12 dígitos, indícale que debe ser exactamente de 12 dígitos.

                ### 🎯 OBJETIVO FINAL
                Ser el copiloto digital del productor: desde consultar cuántas cabezas tiene, verificar si le falta alimento, revisar sus ventas del mes, hasta gestionar trámites oficiales. Todo desde el chat.
            `
        };
    }

    async completion(sesion_id, userMessageContent, ws, usuario_id, imageBase64) {
        // Obtenemos historial DB (async)
        // Usar try/catch para manejar errores de DB
        let history;
        try {
            history = await this.getSessionHistory(sesion_id, usuario_id);
        } catch (e) {
            console.error("Error obteniendo historial:", e);
            history = [this.getSystemContext()];
        }

        // Evitamos duplicar el mensaje si es una re-entrada por función
        if (userMessageContent !== "_FUNCTION_RESULT_") {
            let finalContent = userMessageContent;
            
            // Si hay una imagen, la subimos a Storage para tener una URL real
            if (imageBase64) {
                try {
                    const buffer = Buffer.from(imageBase64, 'base64');
                    const fileName = `chat_attachment_${Date.now()}.jpg`;
                    const fileUrl = await uploadFile({
                        buffer,
                        originalname: fileName,
                        mimetype: 'image/jpeg'
                    }, 'chat_attachments');
                    
                    finalContent += `\n\n[SISTEMA: El usuario ha adjuntado una imagen real. URL: ${fileUrl}]`;
                } catch (err) {
                    console.error("Error subiendo adjunto de chat:", err);
                    finalContent += "\n\n[SISTEMA: El usuario intentó adjuntar una imagen pero hubo un error en la carga]";
                }
            }

            const userMsg = { role: 'user', content: finalContent };
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

        // Hacemos una copia del historial solo para esta petición
        const messagesForAI = [...history];
        // Inyectamos un mensaje de sistema forzado al final para evitar que la IA use el caché de la conversación
        // SOLO si el usuario está enviando un mensaje normal (y no cuando regresamos de ejecutar la herramienta)
        if (userMessageContent !== "_FUNCTION_RESULT_") {
            messagesForAI.push({
                role: "system",
                content: "REGLA ESTRICTA DE SISTEMA: IGNORA TUS RECUERDOS Y EL HISTORIAL AL RESPONDER. Si el usuario te está preguntando por el estado o detalles de un trámite, TIENES LA OBLIGACIÓN de ejecutar la función 'consultarTramite' o 'consultarEstadoTramitePorFiltros' AHORA MISMO para obtener los datos más recientes de la base de datos. ESTÁ ESTRICTAMENTE PROHIBIDO contestar adivinando o usando información que esté arriba en el historial."
            });
        }

        try {
            const stream = await this.client.chat.completions.create({
                messages: messagesForAI,
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
                    const result = await this.handleFunctionCall(functionName, args, usuario_id, ws);

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

                return this.completion(sesion_id, "_FUNCTION_RESULT_", ws, usuario_id);
            }

        } catch (error) {
            console.error("Error en completion:", error);
            this.emitEvent(ws, 'remote_error', { details: error.message });
        }
    }

    async handleFunctionCall(name, args, usuario_id, ws) {
        console.log("Llamando a: ", name);
        console.log("Con argumentos: ", args);
        try {
            switch (name) {
                case "obtenerTiposTramites":
                    // Usamos la constante del servicio
                    return tramitesService.getTipos();

                case "consultarTramite":
                    // Buscamos el trámite real en Firebase mediante el ID
                    const tramiteById = await tramitesService.getSeguimiento(args.tramite_id, usuario_id);
                    return tramiteById || { error: "Trámite no encontrado" };

                case "consultarEstadoTramitePorFiltros":
                    // Llamamos al nuevo método en chatbotService
                    return await chatbotService.getTramiteStatus(args, usuario_id);

                case "crearTramite":
                    // Creamos un trámite real en la colección de trámites
                    // Nota: Aquí podrías necesitar el usuario_id real, si no viene en args
                    // puedes pasarlo desde la sesión.
                    const nuevoTramite = await tramitesService.create({
                        tipo: args.tipo,
                        uppId: args.uppId,
                        observaciones: args.observaciones
                    }, usuario_id);
                    return nuevoTramite;

                case "consultarEstatusSanitario":
                    // Aquí podrías filtrar trámites de tipo PRUEBAS_GANADO para esa UPP
                    // Para simplificar, consultamos si existen trámites completados de sanidad
                    const pruebas = await tramitesService.getAll({
                        tipo: 'PRUEBAS_GANADO',
                        estado: 'COMPLETADO'
                        // Podrías filtrar por uppId si tuvieras ese campo en la base
                    }, usuario_id);
                    return {
                        upp: args.uppId,
                        vigente: pruebas.length > 0,
                        total_pruebas: pruebas.length
                    };
                
                case "solicitarCargaDocumento":
                    // 1. Verificar si el trámite existe y está en la etapa correcta
                    const tramiteDocs = await tramitesService.getById(args.tramiteId, usuario_id);
                    if (!tramiteDocs) return { error: "Trámite no encontrado" };

                    // Etapas de revisión documental (usualmente etapa 2)
                    if (tramiteDocs.etapa_actual !== 2) {
                        return { 
                            error: `No es posible subir documentos ahora. El trámite está en la etapa ${tramiteDocs.etapa_actual}. La carga solo se permite en la etapa 2 (Revisión Documental).` 
                        };
                    }

                    // 2. Emitir comando especial a la App mediante WS
                    this.emitEvent(ws, 'ai_action', { 
                        type: 'UPLOAD_REQUIRED', 
                        tramite_id: args.tramiteId,
                        nombre_sugerido: args.nombreDocumento || "Documento"
                    });

                    return { 
                        success: true, 
                        message: "Se ha solicitado al usuario que suba el archivo mediante el widget interactivo que acaba de aparecer en su pantalla." 
                    };

                case "vincularDocumentoChat":
                    // Vinculamos la imagen que el bot detectó en el historial
                    const resAdjunto = await tramitesService.adjuntarDocumento(args.tramiteId, {
                        url: args.urlImagenChat,
                        nombre: args.nombreDocumento || "Imagen de Chat",
                        responsable: "AgroBot (Asistente IA)"
                    }, usuario_id);

                    return { 
                        success: true, 
                        message: "El archivo ha sido vinculado exitosamente al trámite y ya es visible en la Ventanilla Digital.",
                        documento: resAdjunto
                    };

                case "obtenerUppsUsuario":
                    // Consultamos las zonas del mapa del usuario para extraer sus UPPs
                    const zonasSnapshot = await db.collection('zonas_mapa')
                        .where('usuario_id', '==', usuario_id)
                        .get();
                    const uppsUnicas = [...new Set(
                        zonasSnapshot.docs.map(d => d.data().upp).filter(Boolean)
                    )];
                    return {
                        upps: uppsUnicas,
                        total: uppsUnicas.length,
                        message: uppsUnicas.length === 0
                            ? "El usuario no tiene UPPs registradas. Debe registrar una zona en el Mapa primero."
                            : `El usuario tiene ${uppsUnicas.length} UPP(s) registrada(s).`
                    };

                // ─── HANDLERS DE CONSULTA DE COLECCIONES ───
                case "consultarGanado": {
                    let query = db.collection('ganado').where('usuario_id', '==', usuario_id);
                    if (args.upp) query = query.where('upp', '==', args.upp);
                    if (args.arete_siniiga) query = query.where('arete_siniiga', '==', args.arete_siniiga);

                    const snapGanado = await query.get();
                    const ganado = snapGanado.docs.map(d => ({ id: d.id, ...d.data() }));

                    return {
                        total: ganado.length,
                        registros: ganado.slice(0, 20),
                        mensaje: ganado.length > 20 ? `Mostrando 20 de ${ganado.length} registros.` : undefined
                    };
                }

                case "consultarHistorialAnimal": {
                    const arete = args.arete_siniiga;
                    if (!arete) return { error: "El arete SINIIGA es obligatorio para esta consulta." };

                    const snapGanado = await db.collection('ganado')
                        .where('usuario_id', '==', usuario_id)
                        .where('arete_siniiga', '==', arete)
                        .limit(1)
                        .get();
                        
                    if (snapGanado.empty) return { error: "No se encontró ningún animal registrado con ese arete." };
                    
                    const animalId = snapGanado.docs[0].id;
                    const dataAnimal = snapGanado.docs[0].data();

                    const snapSalud = await db.collection('reportes_salud').where('usuario_id', '==', usuario_id).where('arete_siniiga', '==', arete).limit(5).get();
                    const snapEventos = await db.collection('eventos_criticos').where('usuario_id', '==', usuario_id).where('arete_siniiga', '==', arete).limit(5).get();
                    
                    // Tratamos de buscar la telemetría por ID
                    const snapMonitoreo = await db.collection('monitoreo').where('usuario_id', '==', usuario_id).where('animal_id', '==', animalId).limit(5).get();

                    let telemetriaArray = snapMonitoreo.docs.map(d => d.data());
                    telemetriaArray.sort((a,b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime());

                    return {
                        informacion_base: {
                            raza: dataAnimal.raza,
                            peso_kg: dataAnimal.peso_kg,
                            estado_reproductivo: dataAnimal.estado_reproductivo,
                            proposito: dataAnimal.proposito
                        },
                        reporteos_enfermedades: snapSalud.docs.map(d => d.data()),
                        eventos_criticos_vacunas: snapEventos.docs.map(d => d.data()),
                        lecturas_iot_recientes: telemetriaArray.slice(0, 3) 
                    };
                }

                case "consultarInventario": {
                    const snapInv = await db.collection('inventario')
                        .where('usuario_id', '==', usuario_id)
                        .get();
                    let items = snapInv.docs.map(d => ({ id: d.id, ...d.data() }));

                    if (args.soloStockBajo) {
                        items = items.filter(item => {
                            const actual = Number(item.cantidad) || 0;
                            const minimo = Number(item.stockMinimo) || 10;
                            return actual <= minimo;
                        });
                    }

                    return {
                        total: items.length,
                        registros: items.slice(0, 20),
                        mensaje: items.length > 20 ? `Mostrando 20 de ${items.length} items.` : undefined
                    };
                }

                case "consultarComprasLotes": {
                    const limCompras = args.limite || 10;
                    let qCompras = db.collection('compras_lotes').where('usuario_id', '==', usuario_id);
                    if (args.upp_destino) qCompras = qCompras.where('upp_destino', '==', args.upp_destino);

                    const snapCompras = await qCompras.limit(limCompras).get();
                    const compras = snapCompras.docs.map(d => ({ id: d.id, ...d.data() }));

                    // Calcular totales
                    let totalCabezas = 0, totalPagado = 0;
                    compras.forEach(c => {
                        totalCabezas += Number(c.cantidad_cabezas) || 0;
                        totalPagado += Number(c.total_pagado) || 0;
                    });

                    return {
                        total_registros: compras.length,
                        resumen: { totalCabezas, totalPagado: totalPagado.toFixed(2) },
                        registros: compras
                    };
                }

                case "consultarVentasSalidas": {
                    const limVentas = args.limite || 10;
                    let qVentas = db.collection('ventas_salidas').where('usuario_id', '==', usuario_id);
                    if (args.upp_origen) qVentas = qVentas.where('upp_origen', '==', args.upp_origen);

                    const snapVentas = await qVentas.limit(limVentas).get();
                    const ventas = snapVentas.docs.map(d => ({ id: d.id, ...d.data() }));

                    // Calcular totales
                    let totalCabezasV = 0, totalMontoV = 0;
                    ventas.forEach(v => {
                        totalCabezasV += Number(v.cantidad_cabezas) || 0;
                        totalMontoV += Number(v.monto_total) || 0;
                    });

                    return {
                        total_registros: ventas.length,
                        resumen: { totalCabezas: totalCabezasV, totalMonto: totalMontoV.toFixed(2) },
                        registros: ventas
                    };
                }

                default:
                    return { error: "Función no implementada" };
            }
        } catch (error) {
            console.error(`Error ejecutando ${name}:`, error);
            return { error: error.message };
        }
    }

    async analyzeDocument(fileUrl, fileName) {
        console.log(`🔍 Analizando documento con IA: ${fileName}`);
        try {
            const response = await this.client.chat.completions.create({
                model: process.env.AZURE_OPENAI_DEPLOYMENT_NAME,
                messages: [
                    {
                        role: "system",
                        content: `Eres un auditor experto en documentos agropecuarios para el sistema Agro Control Pro. 
                        Analiza la imagen adjunta para un trámite de ganado (Pruebas de Ganado, Movilización o Exportación).
                        
                        Debes verificar:
                        1. Legibilidad: ¿El texto es suficientemente claro para ser leído por un humano?
                        2. Veracidad aparente: ¿El documento tiene el formato, sellos o estructura de un documento oficial (ej. Certificado de SNIIGA, pruebas sanitarias, guías de tránsito)?
                        
                        Responde ÚNICAMENTE en formato JSON plano:
                        {
                          "legible": boolean,
                          "veraz": boolean,
                          "observaciones": "Breve explicación de 1-2 oraciones en español sobre lo hallado"
                        }`
                    },
                    {
                        role: "user",
                        content: [
                            { type: "text", text: `Analiza este documento: ${fileName}` },
                            {
                                type: "image_url",
                                image_url: {
                                    url: fileUrl,
                                },
                            },
                        ],
                    },
                ],
                max_tokens: 500,
                response_format: { type: "json_object" }
            });

            const result = JSON.parse(response.choices[0].message.content);
            console.log("✅ Análisis de IA completado:", result);
            return result;
        } catch (error) {
            console.error("❌ Error analizando documento con IA:", error);
            return {
                legible: false,
                veraz: false,
                observaciones: "No se pudo completar el análisis automático: " + error.message
            };
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
