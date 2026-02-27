import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Importamos Firebase

class VistaCompraGrupal extends StatefulWidget {
  const VistaCompraGrupal({super.key});

  @override
  State<VistaCompraGrupal> createState() => _VistaCompraGrupalState();
}

class _VistaCompraGrupalState extends State<VistaCompraGrupal> {
  final Color azulAgro = const Color(0xFF01579B);

  // --- CONTROLADORES: Para atrapar lo que escribes ---
  final TextEditingController _proveedorController = TextEditingController();
  final TextEditingController _origenController = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _cabezasController = TextEditingController();
  final TextEditingController _pesoController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();

  // Variable para guardar el cálculo automático del total
  double _totalEstimado = 0.0;

  // --- FUNCIÓN PARA CALCULAR EL TOTAL EN TIEMPO REAL ---
  void _calcularTotal() {
    double peso = double.tryParse(_pesoController.text.trim()) ?? 0.0;
    double precio = double.tryParse(_precioController.text.trim()) ?? 0.0;
    
    setState(() {
      _totalEstimado = peso * precio;
    });
  }

  // --- FUNCIÓN QUE MANDA LOS DATOS A FIREBASE ---
  Future<void> _guardarCompra() async {
    // 1. Validamos que no envíen datos vacíos importantes
    if (_proveedorController.text.trim().isEmpty || _cabezasController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falta el proveedor o la cantidad de cabezas'), backgroundColor: Colors.red),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registrando lote en la nube...')),
    );

    try {
      // 2. Enviamos todo a una colección llamada 'compras_lotes'
      await FirebaseFirestore.instance.collection('compras_lotes').add({
        'proveedor': _proveedorController.text.trim(),
        'origen': _origenController.text.trim(),
        'fecha_indicada': _fechaController.text.trim(),
        'cantidad_cabezas': int.tryParse(_cabezasController.text.trim()) ?? 0,
        'peso_total_kg': double.tryParse(_pesoController.text.trim()) ?? 0.0,
        'precio_por_kilo': double.tryParse(_precioController.text.trim()) ?? 0.0,
        'total_pagado': _totalEstimado,
        'fecha_registro_sistema': FieldValue.serverTimestamp(),
      });

      // 3. Limpiamos las cajas y reseteamos el total
      _proveedorController.clear();
      _origenController.clear();
      _fechaController.clear();
      _cabezasController.clear();
      _pesoController.clear();
      _precioController.clear();
      
      setState(() {
        _totalEstimado = 0.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Compra grupal registrada con éxito!'), backgroundColor: Colors.green),
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
                  _campoTexto("Nombre del Proveedor", Icons.store, TextInputType.text, _proveedorController),
                  const SizedBox(height: 15),
                  _campoTexto("Lugar de Origen (Rancho/Ciudad)", Icons.map, TextInputType.text, _origenController),
                  const SizedBox(height: 15),
                  _campoTexto("Fecha de Compra", Icons.calendar_today, TextInputType.datetime, _fechaController),
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
                      Expanded(child: _campoTexto("Cant. Cabezas", Icons.pets, TextInputType.number, _cabezasController)),
                      const SizedBox(width: 15),
                      // Al escribir en peso, calculamos el total
                      Expanded(child: _campoTexto("Peso Total (Kg)", Icons.monitor_weight, const TextInputType.numberWithOptions(decimal: true), _pesoController, alCambiar: (_) => _calcularTotal())),
                    ],
                  ),
                  const SizedBox(height: 15),
                  // Al escribir en precio, calculamos el total
                  _campoTexto("Precio Pactado por Kilo (\$)", Icons.attach_money, const TextInputType.numberWithOptions(decimal: true), _precioController, alCambiar: (_) => _calcularTotal()),
                  
                  const SizedBox(height: 20),
                  // Resumen dinámico del total
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Total Estimado a Pagar:", style: TextStyle(fontWeight: FontWeight.bold)),
                        Text("\$ ${_totalEstimado.toStringAsFixed(2)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: azulAgro)),
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
                onPressed: _guardarCompra, // <--- Conectado a Firebase
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

  // --- WIDGETS AUXILIARES ---

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