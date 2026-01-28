import 'package:flutter/material.dart';

class VistaManejoGanado extends StatelessWidget {
  const VistaManejoGanado({super.key});

  @override
  Widget build(BuildContext context) {
    final Color azulAgro = const Color(0xFF01579B);

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
              _input("Arete SINIIGA", Icons.qr_code),
              const SizedBox(height: 15),
              _input("Arete Interno", Icons.tag),
            ]),
            const SizedBox(height: 20),
            _buildCard("Biométricos", Icons.monitor_weight, [
              Row(children: [
                Expanded(child: _input("Peso (kg)", Icons.scale)),
                const SizedBox(width: 15),
                Expanded(child: _input("Temperatura", Icons.thermostat)),
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
        Row(children: [Icon(icono, color: Colors.grey), SizedBox(width: 10), Text(titulo, style: TextStyle(fontWeight: FontWeight.bold))]),
        const Divider(height: 30), ...hijos,
      ]),
    );
  }

  Widget _input(String label, IconData icono) {
    return TextField(
      decoration: InputDecoration(
        labelText: label, prefixIcon: Icon(icono, color: Colors.grey),
        filled: true, fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _botonGuardar(Color color) {
    return ElevatedButton.icon(
      onPressed: () {}, icon: const Icon(Icons.check_circle, color: Colors.white),
      label: const Text("GUARDAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20)),
    );
  }
}