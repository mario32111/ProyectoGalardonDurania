import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Importamos Firebase

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

  // --- FUNCIÓN QUE MANDA LOS DATOS A FIREBASE ---
  Future<void> _guardarEnBD() async {
    // 1. Validamos que al menos pongan el arete SINIIGA
    if (_siniigaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El Arete SINIIGA es obligatorio', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guardando registro en la nube...')),
    );

    try {
      // 2. Enviamos todo a una colección llamada 'ganado'
      await FirebaseFirestore.instance.collection('ganado').add({
        'arete_siniiga': _siniigaController.text.trim(),
        'arete_interno': _internoController.text.trim(),
        // Convertimos el peso y temp a números, si está vacío guardamos 0.0
        'peso_kg': double.tryParse(_pesoController.text.trim()) ?? 0.0,
        'temperatura_c': double.tryParse(_tempController.text.trim()) ?? 0.0,
        'fecha_registro': FieldValue.serverTimestamp(),
        'apto_exportacion': true, // Listo para tu lógica de exportación
      });

      // 3. Limpiamos las cajas para registrar la siguiente vaca
      _siniigaController.clear();
      _internoController.clear();
      _pesoController.clear();
      _tempController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Registro guardado con éxito!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader("MANEJO INDIVIDUAL", "Registro de peso y salud", Icons.analytics_rounded, azulAgro),
            const SizedBox(height: 30),
            _buildCard("Identificación", Icons.qr_code, [
              _input("Arete SINIIGA", Icons.qr_code, _siniigaController), // <-- Le pasamos su controlador
              const SizedBox(height: 15),
              _input("Arete Interno", Icons.tag, _internoController), // <-- Le pasamos su controlador
            ]),
            const SizedBox(height: 20),
            _buildCard("Biométricos", Icons.monitor_weight, [
              Row(children: [
                Expanded(child: _input("Peso (kg)", Icons.scale, _pesoController, isNumber: true)), // <-- Controlador y teclado numérico
                const SizedBox(width: 15),
                Expanded(child: _input("Temperatura", Icons.thermostat, _tempController, isNumber: true)), // <-- Controlador y teclado numérico
              ]),
            ]),
            const SizedBox(height: 30),
            Align(alignment: Alignment.centerRight, child: _botonGuardar(azulAgro)),
          ],
        ),
      ),
    );
  }

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
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(icono, color: Colors.grey), const SizedBox(width: 10), Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold))]),
        const Divider(height: 30), ...hijos,
      ]),
    );
  }

  // Modificamos tu input para que acepte el controlador y decida si es número o texto
  Widget _input(String label, IconData icono, TextEditingController controlador, {bool isNumber = false}) {
    return TextField(
      controller: controlador, // <-- Aquí conectamos el campo de texto
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, // <-- Saca teclado numérico si se ocupa
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icono, color: Colors.grey),
        filled: true, fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _botonGuardar(Color color) {
    return ElevatedButton.icon(
      onPressed: _guardarEnBD, // <-- ¡Aquí llamamos a la función de Firebase!
      icon: const Icon(Icons.check_circle, color: Colors.white),
      label: const Text("GUARDAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
    );
  }
}