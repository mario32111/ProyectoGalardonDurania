import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- AGREGADO PARA UID
import 'historial_individual.dart';

class VistaManejoGanado extends StatefulWidget {
  const VistaManejoGanado({super.key});

  @override
  State<VistaManejoGanado> createState() => _VistaManejoGanadoState();
}

class _VistaManejoGanadoState extends State<VistaManejoGanado> {
  final Color azulAgro = const Color(0xFF01579B);

  // --- CONTROLADORES: Para atrapar lo que escribes ---
  final TextEditingController _siniigaController = TextEditingController();
  final TextEditingController _internoController = TextEditingController();
  final TextEditingController _pesoController = TextEditingController();
  final TextEditingController _tempController = TextEditingController();
  
  // --- GESTIÓN DE UPPS DESDE EL MAPA ---
  List<String> _uppsDisponibles = [];
  String? _uppSeleccionada; 
  bool _cargandoUpps = true;

  // --- VARIABLE PARA EL BLOQUEO DE SEGURIDAD ---
  bool _estaGuardando = false;

  @override
  void initState() {
    super.initState();
    _obtenerUppsDelMapa();
  }

  Future<void> _obtenerUppsDelMapa() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('zonas_mapa')
          .where('usuario_id', isEqualTo: user.uid)
          .get();

      // Extraemos solo el campo 'upp' y quitamos duplicados
      final conjuntoUpps = snapshot.docs
          .map((doc) => doc.data()['upp']?.toString() ?? '')
          .where((upp) => upp.isNotEmpty)
          .toSet();

      if (mounted) {
        setState(() {
          _uppsDisponibles = conjuntoUpps.toList();
          _cargandoUpps = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar UPPs: $e");
      if (mounted) setState(() => _cargandoUpps = false);
    }
  }
  // --- FUNCIÓN QUE MANDA LOS DATOS A FIREBASE ---
  Future<void> _guardarEnBD() async {
    // 1. Validamos que al menos pongan el arete SINIIGA
    if (_siniigaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El Arete SINIIGA es obligatorio', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      return;
    }

    String uppGuardar = _uppSeleccionada ?? 'Sin UPP asignada';

    // Activamos la ruedita de carga y bloqueamos el botón
    setState(() {
      _estaGuardando = true;
    });

    try {
      // 2. Enviamos todo a una colección llamada 'ganado'
      final user = FirebaseAuth.instance.currentUser;
      
      await FirebaseFirestore.instance.collection('ganado').add({
        'usuario_id': user?.uid ?? 'anonimo', // Asociar al usuario actual
        'upp': uppGuardar,   // <--- USAR UPP SELECCIONADA O FALLBACK
        'arete_siniiga': _siniigaController.text.trim(),
        'arete_interno': _internoController.text.trim(),
        // Convertimos el peso y temp a números, si está vacío guardamos 0.0
        'peso_kg': double.tryParse(_pesoController.text.trim()) ?? 0.0,
        'temperatura_c': double.tryParse(_tempController.text.trim()) ?? 0.0,
        'fecha_registro': FieldValue.serverTimestamp(),
        'apto_exportacion': true, 
      });

      // 3. Limpiamos las cajas para registrar la siguiente vaca
      _siniigaController.clear();
      _internoController.clear();
      // No limpiamos el selector de UPP para agilizar registros múltiples en el mismo sitio
      _pesoController.clear();
      _tempController.clear();

      // Mostramos mensaje de éxito solo si la pantalla sigue abierta
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Registro de animal guardado con éxito!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      // Mostramos mensaje de error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      // Apagamos la ruedita de carga, haya fallado o no
      if (mounted) {
        setState(() {
          _estaGuardando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Cambié a gris claro para mantener consistencia con las otras pantallas
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader("MANEJO INDIVIDUAL", "Registro de peso y salud", Icons.analytics_rounded, azulAgro),
            const SizedBox(height: 30),
            
            _buildCard("Identificación y Ubicación", Icons.qr_code, [
              _input("Arete SINIIGA", Icons.qr_code, _siniigaController), 
              const SizedBox(height: 15),
              
              // --- NUEVO: SELECTOR DE UPPS DESDE EL MAPA ---
              if (_cargandoUpps) 
                const LinearProgressIndicator()
              else if (_uppsDisponibles.isEmpty)
                TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: "Coto / Zona (UPP)",
                    hintText: "Sin zonas registradas en el mapa",
                    prefixIcon: const Icon(Icons.pin, color: Colors.grey),
                    filled: true, fillColor: Colors.red[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                )
              else 
                DropdownButtonFormField<String>(
                  value: _uppSeleccionada,
                  hint: const Text("Seleccionar UPP de ubicación"),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: "Coto / Zona (UPP)",
                    prefixIcon: const Icon(Icons.pin, color: Colors.grey),
                    filled: true, fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  items: _uppsDisponibles.map((upp) => DropdownMenuItem(value: upp, child: Text(upp))).toList(),
                  onChanged: (val) => setState(() => _uppSeleccionada = val),
                ),

              const SizedBox(height: 15),
              _input("Arete Interno (Opcional)", Icons.tag, _internoController), 
            ]),
            
            const SizedBox(height: 20),
            
            _buildCard("Datos Biométricos", Icons.monitor_weight, [
              Row(
                children: [
                  Expanded(child: _input("Peso (kg)", Icons.scale, _pesoController, isNumber: true)), 
                  const SizedBox(width: 15),
                  Expanded(child: _input("Temp. (°C)", Icons.thermostat, _tempController, isNumber: true)), 
                ]
              ),
            ]),
            
            const SizedBox(height: 40),
            
            // Usamos SizedBox para que el botón ocupe todo el ancho, igual que en Ventas y Compras
            SizedBox(
              width: double.infinity,
              height: 55,
              child: _botonGuardar(azulAgro),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const VistaHistorialIndividual()));
                },
                icon: Icon(Icons.history_edu, color: azulAgro),
                label: Text("VER HISTORIAL DE ANIMAL", style: TextStyle(color: azulAgro, fontWeight: FontWeight.bold, fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: azulAgro, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildHeader(String titulo, String subtitulo, IconData icono, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icono, size: 32, color: color),
        ),
        const SizedBox(width: 15),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          Text(subtitulo, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ]),
      ],
    );
  }

  Widget _buildCard(String titulo, IconData icono, List<Widget> hijos) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16),
        // Agregamos la misma sombra bonita que tienen las otras pantallas
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icono, color: Colors.grey), const SizedBox(width: 10), Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold))]),
        const Divider(height: 30), 
        ...hijos,
      ]),
    );
  }

  Widget _input(String label, IconData icono, TextEditingController controlador, {bool isNumber = false}) {
    return TextField(
      controller: controlador, 
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, 
      decoration: InputDecoration(
        labelText: label, 
        prefixIcon: Icon(icono, color: Colors.grey),
        filled: true, 
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _botonGuardar(Color color) {
    return ElevatedButton.icon(
      onPressed: _estaGuardando ? null : _guardarEnBD, // Bloquea el botón si está cargando
      icon: _estaGuardando 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(Icons.check_circle, color: Colors.white),
      label: Text(
        _estaGuardando ? "GUARDANDO..." : "REGISTRAR ANIMAL", 
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color, 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 5,
      ),
    );
  }
}