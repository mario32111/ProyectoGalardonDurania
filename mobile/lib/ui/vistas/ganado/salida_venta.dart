import 'package:flutter/material.dart';

class VistaSalidaVenta extends StatelessWidget {
  const VistaSalidaVenta({super.key});

  @override
  Widget build(BuildContext context) {
    // Definimos el color aquí adentro para usarlo en la UI
    final Color verdeVenta = const Color(0xFF2E7D32);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
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
                  decoration: BoxDecoration(
                    color: verdeVenta.withOpacity(0.1), 
                    borderRadius: BorderRadius.circular(10)
                  ),
                  child: Icon(Icons.attach_money, color: verdeVenta, size: 32),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("REGISTRAR VENTA", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: verdeVenta)),
                    const Text("Salida de ganado y facturación", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 30),

            // --- SECCIÓN 1: CLIENTE ---
            _tituloSeccion("Información del Cliente"),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: _decoracionTarjeta(),
              child: Column(
                children: [
                  _campoTexto("Cliente / Comprador", Icons.person_outline, TextInputType.text),
                  const SizedBox(height: 15),
                  _campoTexto("Destino (Rastro/Engorda)", Icons.local_shipping_outlined, TextInputType.text),
                  const SizedBox(height: 15),
                  _campoTexto("Fecha de Salida", Icons.calendar_today, TextInputType.datetime),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // --- SECCIÓN 2: DATOS ECONÓMICOS ---
            _tituloSeccion("Detalles Económicos"),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: _decoracionTarjeta(),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _campoTexto("Cabezas", Icons.pets, TextInputType.number)),
                      const SizedBox(width: 15),
                      Expanded(child: _campoTexto("Peso Total (Kg)", Icons.scale, TextInputType.number)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _campoTexto("Precio Venta por Kg (\$)", Icons.price_check, TextInputType.number),
                  
                  const SizedBox(height: 25),
                  const Divider(),
                  const SizedBox(height: 10),

                  // TOTAL
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("MONTO TOTAL:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text("\$ 0.00", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: verdeVenta)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- BOTÓN CORREGIDO ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: verdeVenta,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                onPressed: () {}, 
                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
                // ⚠️ AQUÍ ESTABA EL ERROR: Cambiamos 'child' por 'label'
                label: const Text("FINALIZAR VENTA", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------
  // FUNCIONES DE AYUDA
  // -----------------------------------------------------------

  Widget _tituloSeccion(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54)),
    );
  }

  BoxDecoration _decoracionTarjeta() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 5))],
    );
  }

  Widget _campoTexto(String label, IconData icono, TextInputType tipo) {
    return TextField(
      keyboardType: tipo,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icono, color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
    );
  }

}