import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Modelo simple para cada mensaje del chat
class ChatMessage {
  final String emisor; // 'user' o 'bot'
  String texto;
  bool isStreaming; // true mientras se reciben chunks

  ChatMessage({
    required this.emisor,
    required this.texto,
    this.isStreaming = false,
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
  // Para web (flutter run -d edge/chrome): usa localhost
  // Para emulador Android: usa 10.0.2.2 en vez de localhost
  // Para dispositivo físico: usa la IP de tu PC en la red local
  static const String _serverUrl = 'http://localhost:3000';
  // ══════════════════════════════════════════════════════════

  late final String _sessionId;
  bool _enviando = false;
  http.Client? _httpClient;

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
            '¡Hola! 👋 Soy **AgroBot**, tu asistente ganadero.\n\nPregúntame lo que necesites sobre el manejo de tu finca.',
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
  //  ENVIAR MENSAJE CON STREAMING SSE
  // ═══════════════════════════════════════════════════════════

  Future<void> _enviarMensaje([String? textoDirecto]) async {
    final texto = textoDirecto ?? _controller.text.trim();
    if (texto.isEmpty || _enviando) return;

    _controller.clear();
    _focusNode.requestFocus();

    setState(() {
      // Agregar mensaje del usuario
      _mensajes.add(ChatMessage(emisor: 'user', texto: texto));
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
      request.body = jsonEncode({'message': texto, 'session_id': _sessionId});

      final response = await _httpClient!.send(request);

      if (response.statusCode != 200) {
        _finalizarConError('Error del servidor (${response.statusCode})');
        return;
      }

      // Leer el stream SSE
      await _leerSSEStream(response.stream);
    } catch (e) {
      _finalizarConError('Error de conexión: $e');
    } finally {
      _httpClient?.close();
      _httpClient = null;
    }
  }

  /// Procesa el stream SSE línea por línea (igual que readSSEStream en test-audio.html)
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

            // ai_log se ignora en la UI del chat (son logs internos)
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
          _buildInput(),
        ],
      ),
    );
  }

  /// Header con gradiente azul
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

  /// Área de mensajes
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

  /// Formatea texto básico con negritas (**texto**)
  Widget _buildTextoFormateado(String texto, Color color) {
    // Parsing simple de **bold**
    final spans = <TextSpan>[];
    final regExp = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in regExp.allMatches(texto)) {
      // Texto normal antes del bold
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: texto.substring(lastEnd, match.start)));
      }
      // Texto en bold
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
      lastEnd = match.end;
    }
    // Texto restante
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

  /// Indicador de "typing" con tres puntos animados
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

  /// Chips de sugerencias rápidas
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

  /// Input de texto + botón enviar
  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
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
