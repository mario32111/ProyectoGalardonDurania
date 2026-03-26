import 'dart:async';
import 'dart:convert';
import 'dart:io' show File; // Se especifica para evitar conflictos (dart:io no se debe usar directamente en web para File.path etc)
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // PARA DETECTAR NAVEGADOR
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart'; 
import 'package:path_provider/path_provider.dart'; 
import 'package:permission_handler/permission_handler.dart'; 
import 'package:http_parser/http_parser.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; // <--- NUEVO: AUTH DE FIREBASE 

/// Modelo simple para cada mensaje del chat
class ChatMessage {
  final String emisor; // 'user' o 'bot'
  String texto;
  bool isStreaming; // true mientras se reciben chunks
  XFile? imagen; // USAR XFILE PARA COMPATIBILIDAD WEB
  bool isAudio; 

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
  // En Web, si corres en local, 'localhost' está OK. 
  // Si apuntas a una IP externa, asegúrate de actualizarlo.
  // Cambia 'localhost' por tu IP real
  static const String _serverUrl = 'http://192.168.1.72:3000'; 

  // ══════════════════════════════════════════════════════════

  String? _sessionId; 
  bool _cargandoHistorial = false; 
  bool _enviando = false;
  http.Client? _httpClient;
  
  // --- HISTORIAL DE SESIONES ---
  List<dynamic> _listaSesiones = [];
  bool _mostrandoHistorial = false; 
  bool _estaEliminando = false;

  // --- VARIABLES PARA LA CÁMARA/GALERÍA ---
  XFile? _imagenSeleccionada;
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
    _audioRecorder = AudioRecorder();

    // Cargamos el historial al iniciar
    _cargarHistorial();
  }

  // ═══════════════════════════════════════════════════════════
  //  FUNCIONES DE APOYO (AUTH & HISTORIAL)
  // ═══════════════════════════════════════════════════════════

  /// Obtiene los headers de autorización con el token de Firebase
  Future<Map<String, String>> _getAuthHeaders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return {};
    final token = await user.getIdToken();
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }

  /// Carga la lista completa de sesiones y el historial de la última
  Future<void> _cargarHistorial() async {
    setState(() => _cargandoHistorial = true);
    
    try {
      final headers = await _getAuthHeaders();
      if (headers.isEmpty) {
         _finalizarCargaHistorial();
         return;
      }

      final response = await http.get(
        Uri.parse('$_serverUrl/chatbot/historial?limite=20'), 
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List sesiones = data['data']['conversaciones'] ?? [];
        
        setState(() {
          _listaSesiones = sesiones;
        });

        if (sesiones.isNotEmpty && _sessionId == null) {
          // Si no tenemos sesión activa, cargamos la última automáticamente
          _cargarDatosSesion(sesiones.first);
        } else if (sesiones.isEmpty) {
          _crearNuevaSesion();
        }
      } else {
        debugPrint('Error cargando historial: ${response.statusCode}');
        if (_sessionId == null) _crearNuevaSesion();
      }
    } catch (e) {
      debugPrint('Error de conexión al cargar historial: $e');
      if (_sessionId == null) _crearNuevaSesion();
    } finally {
      _finalizarCargaHistorial();
    }
  }

  void _cargarDatosSesion(dynamic sesion) {
    final String sId = sesion['id'] ?? sesion['sesion_id'];
    final List mensajesRaw = sesion['mensajes'] ?? [];

    setState(() {
      _sessionId = sId;
      _mostrandoHistorial = false;
      _mensajes.clear();
      for (var m in mensajesRaw) {
        if (m['role'] == 'system') continue;
        _mensajes.add(ChatMessage(
          emisor: m['role'] == 'user' ? 'user' : 'bot',
          texto: m['content'] ?? '',
        ));
      }
    });
    _moverAlFinal();
  }

  Future<void> _cargarSesionPorId(String id) async {
    setState(() => _cargandoHistorial = true);
    try {
      final headers = await _getAuthHeaders();
      final response = await http.get(
        Uri.parse('$_serverUrl/chatbot/sesion/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _cargarDatosSesion(data['data']);
      }
    } catch (e) {
      debugPrint('Error cargando sesión específica: $e');
    } finally {
      setState(() => _cargandoHistorial = false);
    }
  }

  Future<void> _eliminarSesion(String id) async {
    setState(() => _estaEliminando = true);
    try {
      final headers = await _getAuthHeaders();
      final response = await http.delete(
        Uri.parse('$_serverUrl/chatbot/sesion/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        if (_sessionId == id) {
          setState(() {
            _sessionId = null;
            _mensajes.clear();
          });
          _crearNuevaSesion();
        }
        _cargarHistorial(); 
      }
    } catch (e) {
      debugPrint('Error eliminando sesión: $e');
    } finally {
      setState(() => _estaEliminando = false);
    }
  }

  void _finalizarCargaHistorial() {
    if (mounted) {
      setState(() => _cargandoHistorial = false);
      if (_mensajes.isEmpty) {
        _mensajes.add(ChatMessage(
          emisor: 'bot',
          texto: '¡Hola! 👋 Soy **AgroBot**, tu asistente ganadero. ¿Cómo puedo ayudarte hoy?',
        ));
      }
    }
  }

  Future<void> _crearNuevaSesion() async {
    try {
      final headers = await _getAuthHeaders();
      final response = await http.post(
        Uri.parse('$_serverUrl/chatbot/sesion/nueva'),
        headers: headers,
      );
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        setState(() {
          _sessionId = data['data']['sesion_id'];
          _mensajes.clear(); 
          _mostrandoHistorial = false;
        });
        _cargarHistorial(); // Refrescar lista
      } else {
         setState(() => _sessionId = const Uuid().v4());
      }
    } catch (e) {
      setState(() => _sessionId = const Uuid().v4());
    }
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
        _imagenSeleccionada = foto;
      });
    }
  }

  Future<void> _toggleMic() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    // EN WEB NO USAMOS PERMISSION_HANDLER PARA EL MICROFONO (SE PIDE AUTOMATICAMENTE)
    if (!kIsWeb) {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permiso de micrófono denegado.')));
        return;
      }
    }
    
    String path = '';
    RecordConfig config;

    if (kIsWeb) {
      // WEB: Usar Opus (WebM) o Wav
      path = ''; // En web el encoder ignora esto y genera Blob URL
      config = const RecordConfig(encoder: AudioEncoder.opus);
    } else {
      // MOVIL
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/agrobot_${DateTime.now().millisecondsSinceEpoch}.m4a';
      config = const RecordConfig(encoder: AudioEncoder.aacLc);
    }

    try {
      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(config, path: path);
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      debugPrint('Error al iniciar grabación: $e');
    }
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
      
      // AGREGAR TOKEN A MULTIPART
      final headers = await _getAuthHeaders();
      request.headers.addAll(headers);

      request.fields['session_id'] = _sessionId ?? "";

      if (kIsWeb) {
        // EN WEB: filePath es una URL Blob, tenemos que descargar los bytes
        final response = await http.get(Uri.parse(filePath));
        final bytes = response.bodyBytes;
        request.files.add(http.MultipartFile.fromBytes(
          'audio', 
          bytes,
          filename: 'recording.webm',
          contentType: MediaType('audio', 'webm'),
        ));
      } else {
        // EN MOVIL: filePath es una ruta al sitema de archivos
        request.files.add(await http.MultipartFile.fromPath(
          'audio', 
          filePath,
          contentType: MediaType('audio', 'm4a'),
        ));
      }

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
    
    if ((texto.isEmpty && _imagenSeleccionada == null) || _enviando || _isRecording || _sessionId == null) return;

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
      
      final headers = await _getAuthHeaders();
      request.headers.addAll(headers);
      
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
            case 'transcription': 
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
        } catch (_) {}
      }
    }

    if (mounted) {
      setState(() {
        botMsg.isStreaming = false;
        _enviando = false;
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
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

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
          Expanded(
            child: _mostrandoHistorial ? _buildHistorialView() : _buildChatArea(),
          ),
          if (!_mostrandoHistorial && _mensajes.length <= 1) _buildSugerencias(),
          
          if (_imagenSeleccionada != null)
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20, top: 10),
              child: Stack(
                children: [
                   ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb 
                      ? Image.network(_imagenSeleccionada!.path, width: 80, height: 80, fit: BoxFit.cover)
                      : Image.file(File(_imagenSeleccionada!.path), width: 80, height: 80, fit: BoxFit.cover),
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
              IconButton(
                onPressed: () {
                  setState(() => _mostrandoHistorial = !_mostrandoHistorial);
                  if (_mostrandoHistorial) _cargarHistorial();
                },
                icon: Icon(
                  _mostrandoHistorial ? Icons.chat_bubble_rounded : Icons.history_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_mostrandoHistorial ? "Tus Conversaciones" : "AgroBot Voice", 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  if (!_mostrandoHistorial)
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text("En línea", style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                      ],
                    ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (!_mostrandoHistorial)
                IconButton(
                  onPressed: () {
                    setState(() {
                      _sessionId = null;
                      _mensajes.clear();
                    });
                    _crearNuevaSesion();
                  },
                  icon: const Icon(Icons.add_comment_rounded, color: Colors.white),
                  tooltip: "Nueva Sesión",
                ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistorialView() {
    return Container(
      color: fondoGris,
      child: Stack(
        children: [
          _listaSesiones.isEmpty && !_cargandoHistorial
              ? const Center(child: Text("No hay conversaciones previas."))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _listaSesiones.length,
                  itemBuilder: (context, index) {
                    final sesion = _listaSesiones[index];
                    final String id = sesion['id'] ?? sesion['sesion_id'];
                    final String fecha = sesion['fecha_inicio'] ?? '';
                    final List msgs = sesion['mensajes'] ?? [];
                    final String ultimoTxt = msgs.isNotEmpty ? msgs.last['content'] : 'Conversación vacía';
                    final bool esActiva = _sessionId == id;

                    return Card(
                      elevation: esActiva ? 2 : 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                        side: esActiva ? BorderSide(color: azulClaro, width: 2) : BorderSide.none,
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: esActiva ? azulPrincipal : Colors.grey.shade200,
                          child: Icon(Icons.chat_outlined, color: esActiva ? Colors.white : Colors.grey),
                        ),
                        title: Text(
                          "Sesión: ${id.substring(0, 8)}...",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ultimoTxt, maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(fecha.split('T').first, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: _estaEliminando ? null : () => _showConfirmDelete(id),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                        onTap: () => _cargarSesionPorId(id),
                      ),
                    );
                  },
                ),
          if (_cargandoHistorial || _estaEliminando)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  void _showConfirmDelete(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Eliminar Sesión"),
        content: const Text("¿Estás seguro de que deseas eliminar esta conversación?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _eliminarSesion(id);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return Container(
      color: fondoGris,
      child: Stack(
        children: [
          ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _mensajes.length,
            itemBuilder: (context, index) {
              final msg = _mensajes[index];
              return _buildBurbuja(msg);
            },
          ),
          if (_cargandoHistorial)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
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
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: esBot ? Colors.white : azulPrincipal,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(esBot ? 4 : 18),
            bottomRight: Radius.circular(esBot ? 18 : 4),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
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
                    Text('AgroBot', style: TextStyle(fontSize: 11, color: azulClaro, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            if (msg.imagen != null) 
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10), 
                  child: kIsWeb 
                    ? Image.network(msg.imagen!.path)
                    : Image.file(File(msg.imagen!.path))
                ),
              ),
            if (msg.texto.isNotEmpty)
              _buildTextoFormateado(msg.texto, esBot ? Colors.black87 : Colors.white),
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
      if (match.start > lastEnd) spans.add(TextSpan(text: texto.substring(lastEnd, match.start)));
      spans.add(TextSpan(text: match.group(1), style: const TextStyle(fontWeight: FontWeight.bold)));
      lastEnd = match.end;
    }
    if (lastEnd < texto.length) spans.add(TextSpan(text: texto.substring(lastEnd)));
    return RichText(text: TextSpan(style: TextStyle(color: color, fontSize: 14.5, height: 1.4), children: spans.isEmpty ? [TextSpan(text: texto)] : spans));
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
                width: 8, height: 8,
                decoration: BoxDecoration(color: azulClaro.withValues(alpha: value), shape: BoxShape.circle),
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
        spacing: 8, runSpacing: 6,
        children: _sugerencias.map((s) {
          return ActionChip(
            label: Text(s, style: const TextStyle(fontSize: 12)),
            backgroundColor: Colors.white,
            side: BorderSide(color: azulClaro.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            onPressed: () => _enviarMensaje(s),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(left: 10, right: 16, top: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -2))]),
      child: _mostrandoHistorial 
        ? Center(child: Text("Selecciona una sesión para continuar", style: TextStyle(color: Colors.grey.shade600, fontStyle: FontStyle.italic)))
        : (_isRecording ? _buildRecordingState() : Row(
        children: [
          IconButton(icon: Icon(Icons.attach_file, color: azulPrincipal, size: 26), onPressed: _enviando ? null : _seleccionarImagen),
          Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: fondoGris, borderRadius: BorderRadius.circular(25)), child: TextField(controller: _controller, focusNode: _focusNode, onSubmitted: (_) => _enviarMensaje(), textInputAction: TextInputAction.send, decoration: const InputDecoration(hintText: 'Escribe tu mensaje...', border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 12))))),
          const SizedBox(width: 8),
          GestureDetector(onTap: _enviando ? null : _toggleMic, child: Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, border: Border.all(color: azulClaro.withValues(alpha: 0.5)), shape: BoxShape.circle), child: Icon(Icons.mic, color: azulClaro, size: 22))),
          const SizedBox(width: 8),
          GestureDetector(onTap: _enviando ? null : () => _enviarMensaje(), child: Container(width: 44, height: 44, decoration: BoxDecoration(gradient: LinearGradient(colors: _enviando ? [Colors.grey.shade400, Colors.grey.shade500] : [azulClaro, azulPrincipal]), shape: BoxShape.circle, boxShadow: _enviando ? [] : [BoxShadow(color: azulPrincipal.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]), child: const Icon(Icons.send_rounded, color: Colors.white, size: 20))),
        ],
      )),
    );
  }

  Widget _buildRecordingState() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text("🔴 Grabando...", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 20),
        GestureDetector(onTap: _toggleMic, child: Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]), child: const Icon(Icons.stop_rounded, color: Colors.white, size: 28))),
      ],
    );
  }
}