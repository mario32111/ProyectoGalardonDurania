import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Importamos Firebase

class VistaComprarProducto extends StatefulWidget {
  const VistaComprarProducto({super.key});

  @override
  State<VistaComprarProducto> createState() => _VistaComprarProductoState();
}

class _VistaComprarProductoState extends State<VistaComprarProducto> {
  final Color naranjaInventario = const Color(0xFFEF6C00);

  // --- CONTROLADORES ---
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _proveedorController = TextEditingController();
  final TextEditingController _cantidadController = TextEditingController();
  final TextEditingController _costoController = TextEditingController();

  // --- VARIABLES PARA LOS MENÚS DESPLEGABLES ---
  String? _categoriaSeleccionada;
  String? _unidadSeleccionada;

  // --- VARIABLE PARA EL CÁLCULO TOTAL ---
  double _costoTotal = 0.0;

  // --- FUNCIÓN PARA CALCULAR EL TOTAL EN TIEMPO REAL ---
  void _calcularTotal() {
    double cantidad = double.tryParse(_cantidadController.text.trim()) ?? 0.0;
    double costo = double.tryParse(_costoController.text.trim()) ?? 0.0;
    
    setState(() {
      _costoTotal = cantidad * costo;
    });
  }

  // --- FUNCIÓN QUE MANDA LOS DATOS A FIREBASE ---
  Future<void> _guardarEnInventario() async {
    // 1. Validamos que no falten datos clave
    if (_nombreController.text.trim().isEmpty || _cantidadController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor llena el nombre y la cantidad'), backgroundColor: Colors.red),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Agregando al inventario...')),
    );

    try {
      // 2. Guardamos en la colección 'inventario' (La que lee tu pantalla de Stock)
      await FirebaseFirestore.instance.collection('inventario').add({
        'nombre': _nombreController.text.trim(),
        'categoria': _categoriaSeleccionada ?? 'Sin categoría',
        'proveedor': _proveedorController.text.trim(),
        'cantidad_actual': double.tryParse(_cantidadController.text.trim()) ?? 0.0,
        'capacidad_maxima': 1000.0, // Un valor por defecto para que la barra gráfica funcione
        'unidad': _unidadSeleccionada ?? 'Und',
        'costo_unitario': double.tryParse(_costoController.text.trim()) ?? 0.0,
        'costo_total_compra': _costoTotal,
        'fecha_ingreso': FieldValue.serverTimestamp(),
      });

      // 3. Limpiamos el formulario
      _nombreController.clear();
      _proveedorController.clear();
      _cantidadController.clear();
      _costoController.clear();
      
      setState(() {
        _costoTotal = 0.0;
        _categoriaSeleccionada = null;
        _unidadSeleccionada = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Producto agregado al stock con éxito!'), backgroundColor: Colors.green),
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
                  _campoTexto("Nombre del Producto", Icons.label_outline, TextInputType.text, _nombreController),
                  const SizedBox(height: 15),
                  
                  // Dropdown REAL para Categoría
                  DropdownButtonFormField<String>(
                    value: _categoriaSeleccionada,
                    decoration: _inputDecoration("Categoría", Icons.category),
                    items: ["Alimento / Grano", "Medicina / Vacuna", "Equipo / Herramienta"]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _categoriaSeleccionada = val;
                      });
                    },
                  ),
                  
                  const SizedBox(height: 15),
                  _campoTexto("Proveedor", Icons.storefront, TextInputType.text, _proveedorController),
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
                      Expanded(child: _campoTexto("Cantidad", Icons.format_list_numbered, const TextInputType.numberWithOptions(decimal: true), _cantidadController, alCambiar: (_) => _calcularTotal())),
                      const SizedBox(width: 15),
                      Expanded(
                        // Dropdown REAL para la Unidad
                        child: DropdownButtonFormField<String>(
                          value: _unidadSeleccionada,
                          decoration: _inputDecoration("Unidad", Icons.straighten),
                          items: ["Kg", "Litros", "Dosis", "Sacos", "Piezas"]
                              .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) {
                            setState(() {
                              _unidadSeleccionada = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _campoTexto("Costo Unitario (\$)", Icons.attach_money, const TextInputType.numberWithOptions(decimal: true), _costoController, alCambiar: (_) => _calcularTotal()),
                  
                  const SizedBox(height: 25),
                  const Divider(),
                  
                  // CÁLCULO TOTAL
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("COSTO TOTAL:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text("\$ ${_costoTotal.toStringAsFixed(2)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: naranjaInventario)),
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
                onPressed: _guardarEnInventario, // <--- Conectado a Firebase
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

  // Modificado para aceptar controladores y onChanged
  Widget _campoTexto(String label, IconData icono, TextInputType tipo, TextEditingController controlador, {Function(String)? alCambiar}) {
    return TextField(
      controller: controlador,
      keyboardType: tipo,
      onChanged: alCambiar,
      decoration: _inputDecoration(label, icono),
    );
  }

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