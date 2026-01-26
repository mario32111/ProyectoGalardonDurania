const { createAzureClient } = require('../config/azureConfig.js');

const tools = [
    // ========== GESTIÓN DE GANADO ==========
    {
        type: "function",
        function: {
            name: "obtenerGanado",
            description: "Obtiene la lista completa de ganado registrado o filtra por criterios específicos.",
            parameters: {
                type: "object",
                properties: {
                    filtros: {
                        type: "object",
                        description: "Filtros opcionales para la búsqueda",
                        properties: {
                            raza: { type: "string", description: "Raza del ganado (ej: Holstein, Angus)" },
                            estado_salud: { type: "string", description: "Estado de salud del animal" },
                            edad_min: { type: "number", description: "Edad mínima en años" },
                            edad_max: { type: "number", description: "Edad máxima en años" }
                        }
                    }
                },
                required: []
            }
        }
    },
    {
        type: "function",
        function: {
            name: "registrarGanado",
            description: "Registra un nuevo animal en el sistema ganadero.",
            parameters: {
                type: "object",
                properties: {
                    nombre: { type: "string", description: "Nombre o identificación del animal" },
                    raza: { type: "string", description: "Raza del ganado" },
                    edad: { type: "number", description: "Edad del animal en años" },
                    peso: { type: "number", description: "Peso del animal en kilogramos" },
                    estado_salud: { type: "string", description: "Estado de salud actual" },
                    fecha_ingreso: { type: "string", description: "Fecha de ingreso en formato YYYY-MM-DD" }
                },
                required: ["nombre", "raza"]
            }
        }
    },
    {
        type: "function",
        function: {
            name: "consultarGanado",
            description: "Consulta información detallada de un animal específico por su ID.",
            parameters: {
                type: "object",
                properties: {
                    ganado_id: { type: "string", description: "ID único del animal a consultar" }
                },
                required: ["ganado_id"]
            }
        }
    },
    {
        type: "function",
        function: {
            name: "actualizarGanado",
            description: "Actualiza la información de un animal existente (peso, estado de salud, etc.).",
            parameters: {
                type: "object",
                properties: {
                    ganado_id: { type: "string", description: "ID del animal a actualizar" },
                    datos: {
                        type: "object",
                        description: "Datos a actualizar",
                        properties: {
                            peso: { type: "number" },
                            estado_salud: { type: "string" },
                            observaciones: { type: "string" }
                        }
                    }
                },
                required: ["ganado_id", "datos"]
            }
        }
    },

    // ========== GESTIÓN DE TRÁMITES ==========
    {
        type: "function",
        function: {
            name: "obtenerTiposTramites",
            description: "Obtiene todos los tipos de trámites disponibles y sus etapas (Pruebas de Ganado, Movilización, Exportación).",
            parameters: {
                type: "object",
                properties: {},
                required: []
            }
        }
    },
    {
        type: "function",
        function: {
            name: "consultarTramite",
            description: "Consulta el estado actual de un trámite específico, incluyendo la etapa en la que se encuentra.",
            parameters: {
                type: "object",
                properties: {
                    tramite_id: {
                        type: "string",
                        description: "ID del trámite o número de trámite (ej: TRM-2026-001)"
                    }
                },
                required: ["tramite_id"]
            }
        }
    },
    {
        type: "function",
        function: {
            name: "obtenerSeguimientoTramite",
            description: "Obtiene el seguimiento completo de un trámite con historial de todas las etapas por las que ha pasado.",
            parameters: {
                type: "object",
                properties: {
                    tramite_id: { type: "string", description: "ID del trámite" }
                },
                required: ["tramite_id"]
            }
        }
    },
    {
        type: "function",
        function: {
            name: "crearTramite",
            description: "Crea un nuevo trámite (Pruebas de Ganado, Movilización o Exportación).",
            parameters: {
                type: "object",
                properties: {
                    tipo: {
                        type: "string",
                        enum: ["PRUEBAS_GANADO", "MOVILIZACION", "EXPORTACION"],
                        description: "Tipo de trámite a crear"
                    },
                    usuario_id: { type: "string", description: "ID del usuario solicitante" },
                    ganado_ids: {
                        type: "array",
                        items: { type: "string" },
                        description: "IDs de los animales relacionados al trámite"
                    },
                    observaciones: { type: "string", description: "Observaciones adicionales" }
                },
                required: ["tipo", "usuario_id"]
            }
        }
    },
    {
        type: "function",
        function: {
            name: "obtenerTramitesUsuario",
            description: "Obtiene todos los trámites de un usuario específico.",
            parameters: {
                type: "object",
                properties: {
                    usuario_id: { type: "string", description: "ID del usuario" },
                    estado: {
                        type: "string",
                        enum: ["PENDIENTE", "EN_PROCESO", "COMPLETADO", "CANCELADO"],
                        description: "Filtrar por estado (opcional)"
                    }
                },
                required: ["usuario_id"]
            }
        }
    },
    {
        type: "function",
        function: {
            name: "consultarEstatusSanitario",
            description: "Consulta si una UPP tiene sus pruebas de sanidad vigentes.",
            parameters: {
                type: "object",
                properties: {
                    uppId: {
                        type: "string",
                        description: "La clave de 12 dígitos de la Unidad de Producción Pecuaria."
                    }
                },
                required: ["uppId"]
            }
        }
    },

    // ========== GESTIÓN DE INVENTARIO ==========
    {
        type: "function",
        function: {
            name: "consultarInventario",
            description: "Consulta el inventario completo o filtra por categoría (alimentos, medicamentos, equipos).",
            parameters: {
                type: "object",
                properties: {
                    categoria: {
                        type: "string",
                        description: "Filtrar por categoría: alimento, medicamento, equipo"
                    },
                    stock_bajo: {
                        type: "boolean",
                        description: "Mostrar solo items con stock bajo"
                    }
                },
                required: []
            }
        }
    },
    {
        type: "function",
        function: {
            name: "consultarItemInventario",
            description: "Consulta información detallada de un item específico del inventario.",
            parameters: {
                type: "object",
                properties: {
                    item_id: { type: "string", description: "ID del item a consultar" }
                },
                required: ["item_id"]
            }
        }
    },
    {
        type: "function",
        function: {
            name: "agregarItemInventario",
            description: "Agrega un nuevo item al inventario (alimento, medicamento, equipo, etc.).",
            parameters: {
                type: "object",
                properties: {
                    nombre: { type: "string", description: "Nombre del item" },
                    categoria: { type: "string", description: "Categoría del item" },
                    cantidad: { type: "number", description: "Cantidad disponible" },
                    unidad_medida: { type: "string", description: "Unidad de medida (kg, litros, unidades)" },
                    precio_unitario: { type: "number", description: "Precio por unidad" },
                    proveedor: { type: "string", description: "Nombre del proveedor" }
                },
                required: ["nombre", "categoria", "cantidad"]
            }
        }
    },
    {
        type: "function",
        function: {
            name: "actualizarStockInventario",
            description: "Actualiza el stock de un item del inventario (agregar o restar cantidad).",
            parameters: {
                type: "object",
                properties: {
                    item_id: { type: "string", description: "ID del item" },
                    cantidad: { type: "number", description: "Cantidad a agregar o restar" },
                    operacion: {
                        type: "string",
                        enum: ["agregar", "restar"],
                        description: "Tipo de operación sobre el stock"
                    }
                },
                required: ["item_id", "cantidad", "operacion"]
            }
        }
    },
    {
        type: "function",
        function: {
            name: "obtenerAlertasStockBajo",
            description: "Obtiene lista de items con stock bajo que requieren reabastecimiento.",
            parameters: {
                type: "object",
                properties: {},
                required: []
            }
        }
    },

    // ========== GESTIÓN DE USUARIOS ==========
    {
        type: "function",
        function: {
            name: "consultarUsuario",
            description: "Consulta información de un usuario específico.",
            parameters: {
                type: "object",
                properties: {
                    usuario_id: { type: "string", description: "ID del usuario a consultar" }
                },
                required: ["usuario_id"]
            }
        }
    },
    {
        type: "function",
        function: {
            name: "registrarUsuario",
            description: "Registra un nuevo usuario en la plataforma.",
            parameters: {
                type: "object",
                properties: {
                    nombre: { type: "string", description: "Nombre completo del usuario" },
                    email: { type: "string", description: "Email del usuario" },
                    password: { type: "string", description: "Contraseña" },
                    rol: { type: "string", description: "Rol del usuario (administrador, ganadero, veterinario)" },
                    telefono: { type: "string", description: "Teléfono de contacto" }
                },
                required: ["nombre", "email", "password"]
            }
        }
    },

    // ========== INFORMACIÓN GENERAL ==========
    {
        type: "function",
        function: {
            name: "obtenerEstadisticasGenerales",
            description: "Obtiene estadísticas generales de la plataforma (total de ganado, trámites activos, etc.).",
            parameters: {
                type: "object",
                properties: {},
                required: []
            }
        }
    },
    {
        type: "function",
        function: {
            name: "buscarInformacion",
            description: "Búsqueda general en la plataforma (ganado, trámites, inventario) por palabras clave.",
            parameters: {
                type: "object",
                properties: {
                    termino_busqueda: { type: "string", description: "Término a buscar" },
                    categoria: {
                        type: "string",
                        enum: ["ganado", "tramites", "inventario", "todos"],
                        description: "Categoría donde buscar"
                    }
                },
                required: ["termino_busqueda"]
            }
        }
    }
];

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
## 🐮 Asistente Virtual de Plataforma Ganadera Integral 🐮

Eres un asistente experto en gestión ganadera que ayuda a productores con:

**MÓDULOS DISPONIBLES:**
1. **GESTIÓN DE GANADO**: Registro, consulta y actualización de animales
2. **TRÁMITES**: Pruebas Sanitarias, Movilización y Exportación con seguimiento por etapas
3. **INVENTARIO**: Control de alimentos, medicamentos y equipos
4. **USUARIOS**: Gestión de perfiles y roles

**TIPOS DE TRÁMITES:**
- **PRUEBAS_GANADO**: 6 etapas (Solicitud → Programación → Toma de Muestras → Laboratorio → Resultados → Finalizado)
- **MOVILIZACION**: 6 etapas (Solicitud → Revisión Documental → InspeFcción → Aprobación → Guía Emitida → Finalizado)
- **EXPORTACION**: 7 etapas (Solicitud → Revisión → Certificaciones → Inspección Aduanal → SENASA → Documentación → Finalizado)

**CAPACIDADES:**
- Consultar estado de trámites (como seguimiento de pedidos)
- Registrar y consultar ganado
- Gestionar inventario con alertas de stock bajo
- Buscar información en toda la plataforma
- Proporcionar guía paso a paso para procesos

**INSTRUCCIONES:**
1. Usa las funciones disponibles para obtener información actualizada
2. Proporciona respuestas claras y específicas
3. Para trámites, siempre indica el estado actual y próximos pasos
4. Sugiere acciones preventivas (ej: alertas de stock, renovación de pruebas)
5. Sé proactivo en ofrecer ayuda relacionada

**TONO:** Profesional, amigable y orientado a soluciones.`
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
                tools: tools,
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