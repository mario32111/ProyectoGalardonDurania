import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Importamos Firebase

class VistaSalidaVenta extends StatefulWidget {
  const VistaSalidaVenta({super.key});

  @override
  State<VistaSalidaVenta> createState() => _VistaSalidaVentaState();
}

class _VistaSalidaVentaState extends State<VistaSalidaVenta> {
  final Color verdeVenta = const Color(0xFF2E7D32);

  // --- CONTROLADORES: Para atrapar lo que escribes ---
  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _cabezasController = TextEditingController();
  final TextEditingController _pesoController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();

  // Variable para guardar el cálculo automático del total
  double _montoTotal = 0.0;

  // --- FUNCIÓN PARA CALCULAR EL TOTAL EN TIEMPO REAL ---
  void _calcularTotal() {
    double peso = double.tryParse(_pesoController.text.trim()) ?? 0.0;
    double precio = double.tryParse(_precioController.text.trim()) ?? 0.0;
    
    setState(() {
      _montoTotal = peso * precio;
    });
  }

  // --- FUNCIÓN QUE MANDA LOS DATOS A FIREBASE ---
  Future<void> _guardarVenta() async {
    // 1. Validamos que no envíen datos vacíos importantes
    if (_clienteController.text.trim().isEmpty || _pesoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falta el cliente o el peso de la venta'), backgroundColor: Colors.red),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registrando venta en la nube...')),
    );

    try {
      // 2. Enviamos todo a una colección llamada 'ventas_salidas'
      await FirebaseFirestore.instance.collection('ventas_salidas').add({
        'cliente': _clienteController.text.trim(),
        'destino': _destinoController.text.trim(),
        'fecha_salida': _fechaController.text.trim(),
        'cantidad_cabezas': int.tryParse(_cabezasController.text.trim()) ?? 0,
        'peso_total_kg': double.tryParse(_pesoController.text.trim()) ?? 0.0,
        'precio_venta_kg': double.tryParse(_precioController.text.trim()) ?? 0.0,
        'monto_total': _montoTotal,
        'fecha_registro_sistema': FieldValue.serverTimestamp(),
      });

      // 3. Limpiamos las cajas y reseteamos el total
      _clienteController.clear();
      _destinoController.clear();
      _fechaController.clear();
      _cabezasController.clear();
      _pesoController.clear();
      _precioController.clear();
      
      setState(() {
        _montoTotal = 0.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Venta registrada con éxito!'), backgroundColor: Colors.green),
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
                  _campoTexto("Cliente / Comprador", Icons.person_outline, TextInputType.text, _clienteController),
                  const SizedBox(height: 15),
                  _campoTexto("Destino (Rastro/Engorda)", Icons.local_shipping_outlined, TextInputType.text, _destinoController),
                  const SizedBox(height: 15),
                  _campoTexto("Fecha de Salida", Icons.calendar_today, TextInputType.datetime, _fechaController),
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
                      Expanded(child: _campoTexto("Cabezas", Icons.pets, TextInputType.number, _cabezasController)),
                      const SizedBox(width: 15),
                      Expanded(child: _campoTexto("Peso Total (Kg)", Icons.scale, const TextInputType.numberWithOptions(decimal: true), _pesoController, alCambiar: (_) => _calcularTotal())),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _campoTexto("Precio Venta por Kg (\$)", Icons.price_check, const TextInputType.numberWithOptions(decimal: true), _precioController, alCambiar: (_) => _calcularTotal()),
                  
                  const SizedBox(height: 25),
                  const Divider(),
                  const SizedBox(height: 10),

                  // TOTAL
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("MONTO TOTAL:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      Text("\$ ${_montoTotal.toStringAsFixed(2)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: verdeVenta)),
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
                onPressed: _guardarVenta, // <--- Conectado a Firebase
                icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
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

  // Modificado para aceptar controladores y detectar cambios (onChanged)
  Widget _campoTexto(String label, IconData icono, TextInputType tipo, TextEditingController controlador, {Function(String)? alCambiar}) {
    return TextField(
      controller: controlador,
      keyboardType: tipo,
      onChanged: alCambiar, // Permite ejecutar funciones al escribir
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