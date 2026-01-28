import 'package:flutter/material.dart';

class VistaCompraGrupal extends StatelessWidget {
  const VistaCompraGrupal({super.key});

  @override
  Widget build(BuildContext context) {
    final Color azulAgro = const Color(0xFF01579B);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Fondo gris suave moderno
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: azulAgro.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.local_shipping, color: azulAgro, size: 30),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("NUEVA COMPRA", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: azulAgro)),
                    const Text("Registro de lote o embarque", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 30),

            // --- TARJETA 1: DATOS GENERALES ---
            _buildSectionTitle("Origen y Proveedor"),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  _campoTexto("Nombre del Proveedor", Icons.store, TextInputType.text),
                  const SizedBox(height: 15),
                  _campoTexto("Lugar de Origen (Rancho/Ciudad)", Icons.map, TextInputType.text),
                  const SizedBox(height: 15),
                  _campoTexto("Fecha de Compra", Icons.calendar_today, TextInputType.datetime),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // --- TARJETA 2: DATOS DEL GANADO (ECONÓMICOS) ---
            _buildSectionTitle("Detalles de la Carga"),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: _cardDecoration(),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _campoTexto("Cant. Cabezas", Icons.pets, TextInputType.number)),
                      const SizedBox(width: 15),
                      Expanded(child: _campoTexto("Peso Total (Kg)", Icons.monitor_weight, TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _campoTexto("Precio Pactado por Kilo (\$)", Icons.attach_money, TextInputType.number),
                  
                  const SizedBox(height: 20),
                  // Pequeña alerta visual o resumen
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Estimado a Pagar:", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("\$ 0.00", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: azulAgro)),
                      ],
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- BOTÓN DE GUARDADO ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: azulAgro,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                onPressed: () {}, 
                icon: const Icon(Icons.save, color: Colors.white),
                label: const Text("REGISTRAR COMPRA", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS AUXILIARES (Para no repetir código) ---

  Widget _buildSectionTitle(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
    );
  }

  Widget _campoTexto(String label, IconData icono, TextInputType tipo) {
    return TextField(
      keyboardType: tipo,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icono, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFFF8FAFC), // Fondo muy clarito en el input
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    );
  }
}