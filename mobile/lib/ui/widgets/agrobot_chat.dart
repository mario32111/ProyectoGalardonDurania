import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart'; // <--- PAQUETE NUEVO PARA LAS FOTOS

/// Modelo simple para cada mensaje del chat
class ChatMessage {
  final String emisor; // 'user' o 'bot'
  String texto;
  bool isStreaming; // true mientras se reciben chunks
  File? imagen; // <--- NUEVO: Soporte para la foto en el chat

  ChatMessage({
    required this.emisor,
    required this.texto,
    this.isStreaming = false,
    this.imagen,
  });
}

class AgrobotChatWidget extends StatefulWidget {
  const AgrobotChatWidget({super.key});

  @override
  State<AgrobotChatWidget> createState() => _AgrobotChatWidgetState();
}

class _AgrobotChatWidgetState extends State<AgrobotChatWidget>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<ChatMessage> _mensajes = [];

  // ══════════════════════════════════════════════════════════
  //   CONFIGURACIÓN — CAMBIA ESTO A LA URL DE TU SERVIDOR
  // ══════════════════════════════════════════════════════════
  static const String _serverUrl = 'http://localhost:3000';
  // ══════════════════════════════════════════════════════════

  late final String _sessionId;
  bool _enviando = false;
  http.Client? _httpClient;

  // --- NUEVAS VARIABLES PARA LA CÁMARA/GALERÍA ---
  File? _imagenSeleccionada;
  final ImagePicker _picker = ImagePicker();

  // Colores
  final Color azulPrincipal = const Color(0xFF01579B);
  final Color azulClaro = const Color(0xFF29B6F6);
  final Color fondoGris = const Color(0xFFF5F7FA);

  // Sugerencias rápidas
  final List<String> _sugerencias = [
    '¿Cómo registro un animal?',
    '¿Cómo consulto el inventario?',
    '¿Cómo genero reportes?',
  ];

  @override
  void initState() {
    super.initState();
    _sessionId = const Uuid().v4();
    // Mensaje de bienvenida
    _mensajes.add(
      ChatMessage(
        emisor: 'bot',
        texto:
            '¡Hola! 👋 Soy **AgroBot**, tu asistente ganadero.\n\nPregúntame lo que necesites o **adjunta una foto** para analizarla.',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _httpClient?.close();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  //  FUNCIONES PARA IMAGEN Y ENVÍO DE MENSAJES
  // ═══════════════════════════════════════════════════════════

  // Abre la galería y guarda la foto
  Future<void> _seleccionarImagen() async {
    final XFile? foto = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (foto != null) {
      setState(() {
        _imagenSeleccionada = File(foto.path);
      });
    }
  }

  Future<void> _enviarMensaje([String? textoDirecto]) async {
    final texto = textoDirecto ?? _controller.text.trim();
    
    // Ahora validamos que haya texto O que haya una imagen seleccionada
    if ((texto.isEmpty && _imagenSeleccionada == null) || _enviando) return;

    final imagenAEnviar = _imagenSeleccionada;
    String? base64Image;

    // Convertir imagen a texto base64 para el backend
    if (imagenAEnviar != null) {
      final bytes = await imagenAEnviar.readAsBytes();
      base64Image = base64Encode(bytes);
    }

    _controller.clear();
    _focusNode.unfocus(); // Esconde el teclado para ver la respuesta

    setState(() {
      _imagenSeleccionada = null; // Limpiamos la vista previa
      // Agregar mensaje del usuario (con texto y/o foto)
      _mensajes.add(ChatMessage(emisor: 'user', texto: texto, imagen: imagenAEnviar));
      // Agregar placeholder del bot (se llenará con streaming)
      _mensajes.add(ChatMessage(emisor: 'bot', texto: '', isStreaming: true));
      _enviando = true;
    });
    
    _moverAlFinal();

    try {
      _httpClient = http.Client();
      final request = http.Request(
        'POST',
        Uri.parse('$_serverUrl/chatbot/message'),
      );
      request.headers['Content-Type'] = 'application/json';
      
      // Enviamos el texto y la imagen convertida
      request.body = jsonEncode({
        'message': texto,
        'session_id': _sessionId,
        'image_base64': base64Image,
      });

      final response = await _httpClient!.send(request);

      if (response.statusCode != 200) {
        _finalizarConError('Error del servidor (${response.statusCode})');
        return;
      }

      // Leer el stream SSE (MANTENIDO INTACTO)
      await _leerSSEStream(response.stream);
    } catch (e) {
      _finalizarConError('Error de conexión: $e');
    } finally {
      _httpClient?.close();
      _httpClient = null;
    }
  }

  /// Procesa el stream SSE línea por línea (INTACTO)
  Future<void> _leerSSEStream(http.ByteStream stream) async {
    String buffer = '';
    final botMsg = _mensajes.last;

    await for (final chunk in stream.transform(utf8.decoder)) {
      buffer += chunk;

      // Procesar líneas completas del buffer
      final lines = buffer.split('\n');
      // La última línea puede estar incompleta, la guardamos en buffer
      buffer = lines.removeLast();

      for (final line in lines) {
        if (!line.startsWith('data: ')) continue;

        final raw = line.substring(6).trim(); // quitar "data: "

        if (raw == '[DONE]') {
          // Stream terminado
          if (mounted) {
            setState(() {
              botMsg.isStreaming = false;
              _enviando = false;
            });
          }
          return;
        }

        try {
          final parsed = jsonDecode(raw) as Map<String, dynamic>;
          final event = parsed['event'] as String?;

          switch (event) {
            case 'ai_chunk':
              // Agregar chunk de texto progresivamente
              if (mounted) {
                setState(() {
                  botMsg.texto += parsed['chunk'] as String;
                });
                _moverAlFinal();
              }
              break;

            case 'ai_end':
              // Respuesta completa — usar fullResponse como fuente de verdad
              if (mounted) {
                setState(() {
                  botMsg.texto = parsed['fullResponse'] as String;
                  botMsg.isStreaming = false;
                  _enviando = false;
                });
              }
              break;

            case 'error':
              if (mounted) {
                setState(() {
                  botMsg.texto = '❌ ${parsed['error']}';
                  botMsg.isStreaming = false;
                  _enviando = false;
                });
              }
              break;
          }
        } catch (_) {
          // JSON inválido, ignorar
        }
      }
    }

    // Si el stream terminó sin [DONE]
    if (mounted) {
      setState(() {
        botMsg.isStreaming = false;
        _enviando = false;
        if (botMsg.texto.isEmpty) {
          botMsg.texto = '(Sin respuesta del servidor)';
        }
      });
    }
  }

  void _finalizarConError(String error) {
    if (!mounted) return;
    setState(() {
      final botMsg = _mensajes.last;
      botMsg.texto = '❌ $error';
      botMsg.isStreaming = false;
      _enviando = false;
    });
  }

  void _moverAlFinal() {
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  // ═══════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildChatArea()),
          if (_mensajes.length <= 1) _buildSugerencias(),
          
          // --- NUEVO: VISTA PREVIA DE LA FOTO ANTES DE ENVIARLA ---
          if (_imagenSeleccionada != null)
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20, top: 10),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_imagenSeleccionada!, width: 80, height: 80, fit: BoxFit.cover),
                  ),
                  Positioned(
                    right: 0, top: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _imagenSeleccionada = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 14),
                      ),
                    ),
                  )
                ],
              ),
            ),

          _buildInput(),
        ],
      ),
    );
  }

  /// Header con gradiente azul (INTACTO)
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [azulClaro, azulPrincipal]),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "AgroBot",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "En línea",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// Área de mensajes (INTACTO)
  Widget _buildChatArea() {
    return Container(
      color: fondoGris,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _mensajes.length,
        itemBuilder: (context, index) {
          final msg = _mensajes[index];
          return _buildBurbuja(msg);
        },
      ),
    );
  }

  /// Burbuja de mensaje individual
  Widget _buildBurbuja(ChatMessage msg) {
    final esBot = msg.emisor == 'bot';

    return Align(
      alignment: esBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: esBot ? Colors.white : azulPrincipal,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(esBot ? 4 : 18),
            bottomRight: Radius.circular(esBot ? 18 : 4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ícono del bot
            if (esBot && _mensajes.indexOf(msg) > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.smart_toy_rounded, size: 14, color: azulClaro),
                    const SizedBox(width: 4),
                    Text(
                      'AgroBot',
                      style: TextStyle(
                        fontSize: 11,
                        color: azulClaro,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            // --- NUEVO: SI EL MENSAJE TRAE FOTO, LA MOSTRAMOS ---
            if (msg.imagen != null) 
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10), 
                  child: Image.file(msg.imagen!)
                ),
              ),

            // Texto del mensaje
            if (msg.texto.isNotEmpty)
              _buildTextoFormateado(
                msg.texto,
                esBot ? Colors.black87 : Colors.white,
              ),
            // Indicador de streaming (cursor parpadeante)
            if (msg.isStreaming) _buildStreamingIndicator(msg.texto.isEmpty),
          ],
        ),
      ),
    );
  }

  /// Formatea texto básico con negritas (**texto**) (INTACTO)
  Widget _buildTextoFormateado(String texto, Color color) {
    final spans = <TextSpan>[];
    final regExp = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in regExp.allMatches(texto)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: texto.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < texto.length) {
      spans.add(TextSpan(text: texto.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(color: color, fontSize: 14.5, height: 1.4),
        children: spans.isEmpty ? [TextSpan(text: texto)] : spans,
      ),
    );
  }

  /// Indicador de "typing" con tres puntos animados (INTACTO)
  Widget _buildStreamingIndicator(bool sinTexto) {
    return Padding(
      padding: EdgeInsets.only(top: sinTexto ? 0 : 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.3, end: 1.0),
            duration: Duration(milliseconds: 400 + (i * 200)),
            builder: (context, value, child) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: azulClaro.withOpacity(value),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            },
          );
        }),
      ),
    );
  }

  /// Chips de sugerencias rápidas (INTACTO)
  Widget _buildSugerencias() {
    return Container(
      color: fondoGris,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: _sugerencias.map((s) {
          return ActionChip(
            label: Text(s, style: const TextStyle(fontSize: 12)),
            backgroundColor: Colors.white,
            side: BorderSide(color: azulClaro.withOpacity(0.3)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onPressed: () => _enviarMensaje(s),
          );
        }).toList(),
      ),
    );
  }

  /// Input de texto + botón de adjuntar + botón enviar
  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 10, // Un poco menos de espacio a la izquierda para acomodar el clip
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // --- NUEVO: BOTÓN DEL CLIP PARA LA GALERÍA ---
          IconButton(
            icon: Icon(Icons.attach_file, color: azulPrincipal, size: 26),
            onPressed: _enviando ? null : _seleccionarImagen,
          ),
          
          // Campo de texto
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: fondoGris,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onSubmitted: (_) => _enviarMensaje(),
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Escribe tu mensaje...',
                  hintStyle: TextStyle(color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          
          // Botón enviar
          GestureDetector(
            onTap: _enviando ? null : () => _enviarMensaje(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _enviando
                      ? [Colors.grey.shade400, Colors.grey.shade500]
                      : [azulClaro, azulPrincipal],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: _enviando
                    ? []
                    : [
                        BoxShadow(
                          color: azulPrincipal.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}