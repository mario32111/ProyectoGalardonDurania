import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // --- VARIABLE PARA EL BLOQUEO DE SEGURIDAD ---
  bool _estaGuardando = false;

  // --- FUNCIÓN QUE MANDA LOS DATOS A FIREBASE ---
  Future<void> _guardarEnBD() async {
    // 1. Validamos que al menos pongan el arete SINIIGA
    if (_siniigaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El Arete SINIIGA es obligatorio', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red),
      );
      return;
    }

    // Activamos la ruedita de carga y bloqueamos el botón
    setState(() {
      _estaGuardando = true;
    });

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
            
            _buildCard("Identificación Oficial", Icons.qr_code, [
              _input("Arete SINIIGA", Icons.qr_code, _siniigaController), 
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