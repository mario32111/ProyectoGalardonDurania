import 'package:flutter/material.dart';

class VistaComprarProducto extends StatelessWidget {
  const VistaComprarProducto({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos Naranja para identificar INVENTARIO
    final Color naranjaInventario = const Color(0xFFEF6C00);

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
                    color: naranjaInventario.withOpacity(0.1), 
                    borderRadius: BorderRadius.circular(10)
                  ),
                  child: Icon(Icons.shopping_cart, color: naranjaInventario, size: 32),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("COMPRAR INSUMO", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: naranjaInventario)),
                    const Text("Alta de alimentos o medicinas", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 30),

            // --- SECCIÓN 1: DETALLES DEL PRODUCTO ---
            _tituloSeccion("¿Qué vas a ingresar?"),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: _decoracionTarjeta(),
              child: Column(
                children: [
                  _campoTexto("Nombre del Producto", Icons.label_outline, TextInputType.text),
                  const SizedBox(height: 15),
                  // Simulamos un Dropdown para Categoría
                  DropdownButtonFormField<String>(
                    decoration: _inputDecoration("Categoría", Icons.category),
                    items: ["Alimento / Grano", "Medicina / Vacuna", "Equipo / Herramienta"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) {},
                  ),
                  const SizedBox(height: 15),
                  _campoTexto("Proveedor", Icons.storefront, TextInputType.text),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // --- SECCIÓN 2: CANTIDAD Y COSTO ---
            _tituloSeccion("Inventario y Costos"),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: _decoracionTarjeta(),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _campoTexto("Cantidad", Icons.format_list_numbered, TextInputType.number)),
                      const SizedBox(width: 15),
                      Expanded(
                        // Dropdown pequeño para la unidad
                        child: DropdownButtonFormField<String>(
                          decoration: _inputDecoration("Unidad", Icons.straighten),
                          items: ["Kg", "Litros", "Dosis", "Sacos", "Piezas"]
                              .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _campoTexto("Costo Unitario (\$)", Icons.attach_money, TextInputType.number),
                  
                  const SizedBox(height: 25),
                  const Divider(),
                  
                  // CÁLCULO TOTAL
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("COSTO TOTAL:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text("\$ 0.00", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: naranjaInventario)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- BOTÓN DE ACCIÓN ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: naranjaInventario,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                onPressed: () {}, 
                icon: const Icon(Icons.add_shopping_cart, color: Colors.white, size: 28),
                label: const Text("AGREGAR AL INVENTARIO", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------
  // FUNCIONES DE AYUDA (ESTILOS)
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

  // Widget para texto normal
  Widget _campoTexto(String label, IconData icono, TextInputType tipo) {
    return TextField(
      keyboardType: tipo,
      decoration: _inputDecoration(label, icono),
    );
  }

  // Estilo compartido para TextFields y Dropdowns
  InputDecoration _inputDecoration(String label, IconData icono) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icono, color: Colors.grey),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }
}