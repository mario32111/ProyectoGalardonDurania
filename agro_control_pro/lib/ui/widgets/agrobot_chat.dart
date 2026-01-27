import 'package:flutter/material.dart';

class AgrobotChatWidget extends StatefulWidget {
  const AgrobotChatWidget({super.key});

  @override
  State<AgrobotChatWidget> createState() => _AgrobotChatWidgetState();
}

class _AgrobotChatWidgetState extends State<AgrobotChatWidget> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, dynamic>> _mensajes = [
    {'emisor': 'bot', 'texto': 'Sistema AgroBot iniciado.\nEsperando integración de IA...'}
  ];

  // COLORES AZULES
  final Color azulPrincipal = const Color(0xFF01579B);
  final Color azulClaro = const Color(0xFF29B6F6); // Para el degradado
  final Color fondoGris = const Color(0xFFF5F7FA);

  bool _pensando = false;

  // ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
  //               ESPACIO RELEVANTE PARA DESARROLLADOR
  // ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓
  
  Future<String?> _conectarModeloIA(String preguntaUsuario) async {
    // INYECTAR CÓDIGO DE CONEXIÓN AQUÍ
    return null; 
  }

  // ↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑↑

  void _enviarMensaje() async {
    if (_controller.text.trim().isEmpty) return;
    
    String texto = _controller.text.trim();
    _controller.clear();

    setState(() {
      _mensajes.add({'emisor': 'user', 'texto': texto});
      _pensando = true;
    });
    _moverAlFinal();

    String? respuestaIA = await _conectarModeloIA(texto);

    if (mounted) {
      setState(() {
        _pensando = false;
        if (respuestaIA != null) {
          _mensajes.add({'emisor': 'bot', 'texto': respuestaIA});
        } else {
          _mensajes.add({'emisor': 'bot', 'texto': '[DEV]: Función _conectarModeloIA() vacía. Conecta la API.'});
        }
      });
      _moverAlFinal();
    }
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
        borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // HEADER CON DEGRADADO AZUL
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [azulClaro, azulPrincipal]),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text("AgroBot (Dev Mode)", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                )
              ],
            ),
          ),

          // CHAT AREA
          Expanded(
            child: Container(
              color: fondoGris,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _mensajes.length + (_pensando ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _mensajes.length) return const Text(" Procesando...", style: TextStyle(color: Colors.grey));
                  
                  final msg = _mensajes[index];
                  bool esBot = msg['emisor'] == 'bot';

                  return Align(
                    alignment: esBot ? Alignment.centerLeft : Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      decoration: BoxDecoration(
                        // Burbujas azules para usuario
                        color: esBot ? Colors.white : azulPrincipal,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                      ),
                      child: Text(msg['texto'], style: TextStyle(color: esBot ? Colors.black87 : Colors.white)),
                    ),
                  );
                },
              ),
            ),
          ),

          // INPUT
          Container(
            padding: EdgeInsets.only(left: 20, right: 20, top: 15, bottom: MediaQuery.of(context).viewInsets.bottom + 15),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(color: fondoGris, borderRadius: BorderRadius.circular(30)),
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _enviarMensaje(),
                      decoration: const InputDecoration(hintText: "Escribir...", border: InputBorder.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton(
                  mini: true,
                  elevation: 0,
                  backgroundColor: azulPrincipal, // Botón Azul
                  onPressed: _enviarMensaje,
                  child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}