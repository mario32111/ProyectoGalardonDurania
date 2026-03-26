import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart'; // <--- PAQUETE PARA AUDIO
import 'package:path_provider/path_provider.dart'; // <--- PAQUETE PARA DIRECTORIO TEMP
import 'package:permission_handler/permission_handler.dart'; // <--- PERMISOS
import 'package:http_parser/http_parser.dart'; // <--- PARA EL CONTENT-TYPE DEL AUDIO

/// Modelo simple para cada mensaje del chat
class ChatMessage {
  final String emisor; // 'user' o 'bot'
  String texto;
  bool isStreaming; // true mientras se reciben chunks
  File? imagen; // Soporte para la foto en el chat
  bool isAudio; // Soporte para mensaje de audio enviado

  ChatMessage({
    required this.emisor,
    required this.texto,
    this.isStreaming = false,
    this.imagen,
    this.isAudio = false,
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
  static const String _serverUrl = 'http://192.168.1.72:3000';
  // ══════════════════════════════════════════════════════════

  late final String _sessionId;
  bool _enviando = false;
  http.Client? _httpClient;

  // --- VARIABLES PARA LA CÁMARA/GALERÍA ---
  File? _imagenSeleccionada;
  final ImagePicker _picker = ImagePicker();

  // --- VARIABLES PARA EL MICRÓFONO ---
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;

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
    _audioRecorder = AudioRecorder();

    // Mensaje de bienvenida
    _mensajes.add(
      ChatMessage(
        emisor: 'bot',
        texto:
            '¡Hola! 👋 Soy **AgroBot**, tu asistente ganadero.\n\nPregúntame lo que necesites, envíame un audio o **adjunta una foto** para analizarla.',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _httpClient?.close();
    _audioRecorder.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  //  FUNCIONES PARA IMAGEN, AUDIO Y ENVÍO DE MENSAJES
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

  // ===================================
  // GRABACIÓN DE AUDIO
  // ===================================
  Future<void> _toggleMic() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permiso de micrófono denegado.')));
      return;
    }
    
    final dir = await getTemporaryDirectory();
    final String tempPath = '${dir.path}/agrobot_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: tempPath);
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });
    
    if (path != null) {
      _enviarAudio(path);
    }
  }

  // Enviar audio
  Future<void> _enviarAudio(String filePath) async {
    if (_enviando) return;

    _focusNode.unfocus();

    setState(() {
      _mensajes.add(ChatMessage(emisor: 'user', texto: '🎙️ Enviando audio...', isAudio: true));
      _mensajes.add(ChatMessage(emisor: 'bot', texto: '', isStreaming: true));
      _enviando = true;
    });
    _moverAlFinal();

    try {
      _httpClient = http.Client();
      var request = http.MultipartRequest('POST', Uri.parse('$_serverUrl/chatbot/audio-chat'));
      request.fields['session_id'] = _sessionId;
      request.files.add(await http.MultipartFile.fromPath(
        'audio', 
        filePath,
        contentType: MediaType('audio', 'm4a'),
      ));

      final streamedResponse = await _httpClient!.send(request);

      if (streamedResponse.statusCode != 200) {
        final errorText = await streamedResponse.stream.bytesToString();
        _finalizarConError('Error del servidor: $errorText');
        return;
      }
      
      final responseStream = http.ByteStream(streamedResponse.stream);
      await _leerSSEStream(responseStream);
    } catch (e) {
      _finalizarConError('Error de conexión: $e');
    } finally {
      _httpClient?.close();
      _httpClient = null;
    }
  }

  // Enviar Texto / Imagen
  Future<void> _enviarMensaje([String? textoDirecto]) async {
    final texto = textoDirecto ?? _controller.text.trim();
    
    if ((texto.isEmpty && _imagenSeleccionada == null) || _enviando || _isRecording) return;

    final imagenAEnviar = _imagenSeleccionada;
    String? base64Image;

    if (imagenAEnviar != null) {
      final bytes = await imagenAEnviar.readAsBytes();
      base64Image = base64Encode(bytes);
    }

    _controller.clear();
    _focusNode.unfocus();

    setState(() {
      _imagenSeleccionada = null; 
      _mensajes.add(ChatMessage(emisor: 'user', texto: texto, imagen: imagenAEnviar));
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

      await _leerSSEStream(response.stream);
    } catch (e) {
      _finalizarConError('Error de conexión: $e');
    } finally {
      _httpClient?.close();
      _httpClient = null;
    }
  }

  /// Procesa el stream SSE línea por línea (INTACTO CON SOPORTE TRANSCRIPCIÓN)
  Future<void> _leerSSEStream(http.ByteStream stream) async {
    String buffer = '';
    final botMsg = _mensajes.last;

    await for (final chunk in stream.transform(utf8.decoder)) {
      buffer += chunk;

      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final line in lines) {
        if (!line.startsWith('data: ')) continue;

        final raw = line.substring(6).trim(); 

        if (raw == '[DONE]') {
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
              if (mounted) {
                setState(() {
                  botMsg.texto += parsed['chunk'] as String;
                });
                _moverAlFinal();
              }
              break;

            case 'ai_end':
              if (mounted) {
                setState(() {
                  botMsg.texto = parsed['fullResponse'] as String;
                  botMsg.isStreaming = false;
                  _enviando = false;
                });
              }
              break;

            case 'transcription': // <--- ACTUALIZA EL AUDIO CON LA TRANSCRIPCION REAL
              if (mounted) {
                setState(() {
                  if (_mensajes.length >= 2) {
                     final userMsg = _mensajes[_mensajes.length - 2];
                     if(userMsg.isAudio) {
                       userMsg.texto = '🎙️ "${parsed['text']}"';
                     }
                  }
                });
              }
              break;

            case 'error':
              if (mounted) {
                setState(() {
                  botMsg.texto += '\n❌ ${parsed['error']}';
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
                  color: Colors.white.withValues(alpha: 0.2), // ACTUALIZADO PARA DAR CUMPLIMIENTO A LINTS
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
                    "AgroBot Voice",
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
                          color: Colors.white.withValues(alpha: 0.8),
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
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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

            if (msg.imagen != null) 
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10), 
                  child: Image.file(msg.imagen!)
                ),
              ),

            if (msg.texto.isNotEmpty)
              _buildTextoFormateado(
                msg.texto,
                esBot ? Colors.black87 : Colors.white,
              ),
            
            if (msg.isStreaming) _buildStreamingIndicator(msg.texto.isEmpty),
          ],
        ),
      ),
    );
  }

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
                  color: azulClaro.withValues(alpha: value),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            },
          );
        }),
      ),
    );
  }

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
            side: BorderSide(color: azulClaro.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onPressed: () => _enviarMensaje(s),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 10, 
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: _isRecording 
          ? _buildRecordingState()
          : Row(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_file, color: azulPrincipal, size: 26),
                  onPressed: _enviando ? null : _seleccionarImagen,
                ),
                
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
                const SizedBox(width: 8),

                // MICROPHONE BUTTON
                GestureDetector(
                  onTap: _enviando ? null : _toggleMic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: azulClaro.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(Icons.mic, color: azulClaro, size: 22),
                  ),
                ),
                const SizedBox(width: 8),
                
                // SEND TEXT BUTTON
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
                                color: azulPrincipal.withValues(alpha: 0.3),
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

  Widget _buildRecordingState() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("🔴 Grabando...", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 20),
        GestureDetector(
          onTap: _toggleMic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: const Icon(Icons.stop_rounded, color: Colors.white, size: 28),
          ),
        ),
      ],
    );
  }
}