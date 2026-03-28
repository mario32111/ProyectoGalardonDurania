import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- AGREGADO PARA UID
import 'reporte_lotes.dart';

class VistaSalidaVenta extends StatefulWidget {
  const VistaSalidaVenta({super.key});

  @override
  State<VistaSalidaVenta> createState() => _VistaSalidaVentaState();
}

class _VistaSalidaVentaState extends State<VistaSalidaVenta> {
  final Color verdeVenta = const Color(0xFF2E7D32);

  // --- CONTROLADORES ---
  final TextEditingController _clienteController = TextEditingController();
  final TextEditingController _destinoController = TextEditingController();
  final TextEditingController _fechaController = TextEditingController();
  final TextEditingController _cabezasController = TextEditingController();
  final TextEditingController _pesoController = TextEditingController();  final TextEditingController _precioController = TextEditingController();
  
  // --- GESTIÓN DE UPPS DESDE EL MAPA ---
  List<String> _uppsDisponibles = [];
  String? _uppSeleccionada; 
  bool _cargandoUpps = true;

  double _montoTotal = 0.0;
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
  // --- SELECCIONADOR DE FECHA (CALENDARIO) ---
  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? fechaElegida = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: verdeVenta, // Color del header del calendario
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (fechaElegida != null) {
      setState(() {
        // Formatea la fecha para que se vea como DD/MM/YYYY
        _fechaController.text = "${fechaElegida.day.toString().padLeft(2, '0')}/${fechaElegida.month.toString().padLeft(2, '0')}/${fechaElegida.year}";
      });
    }
  }

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
    if (_clienteController.text.trim().isEmpty || _pesoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falta el cliente o el peso de la venta'), backgroundColor: Colors.red),
      );
      return;
    }

    String uppGuardar = _uppSeleccionada ?? 'Sin UPP asignada';

    setState(() {
      _estaGuardando = true; // Empieza a girar la ruedita
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('ventas_salidas').add({
        'usuario_id': user?.uid ?? 'anonimo', // Asociar al usuario actual
        'upp_origen': uppGuardar, // <--- USAR UPP SELECCIONADA O FALLBACK
        'cliente': _clienteController.text.trim(),
        'destino': _destinoController.text.trim(),
        'fecha_salida': _fechaController.text.trim().isEmpty ? 'Sin fecha' : _fechaController.text.trim(),
        'cantidad_cabezas': int.tryParse(_cabezasController.text.trim()) ?? 0,
        'peso_total_kg': double.tryParse(_pesoController.text.trim()) ?? 0.0,
        'precio_venta_kg': double.tryParse(_precioController.text.trim()) ?? 0.0,
        'monto_total': _montoTotal,
        'fecha_registro_sistema': FieldValue.serverTimestamp(),
      });

      // Limpiamos todo
      _clienteController.clear();
      _destinoController.clear();
      // No limpiamos el selector de UPP
      _fechaController.clear();
      _cabezasController.clear();
      _pesoController.clear();
      _precioController.clear();
      
      setState(() {
        _montoTotal = 0.0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Venta registrada con éxito!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _estaGuardando = false; // Detiene la ruedita pase lo que pase
      });
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
                  
                  // --- NUEVO: SELECTOR DE UPPS ---
                  if (_cargandoUpps)
                    const LinearProgressIndicator()
                  else if (_uppsDisponibles.isEmpty)
                    TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: "UPP Origen (Mapa)",
                        hintText: "Sin zonas registradas en el mapa",
                        prefixIcon: const Icon(Icons.pin, color: Colors.grey),
                        filled: true, fillColor: Colors.red[50],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: _uppSeleccionada,
                      hint: const Text("Seleccionar UPP de origen"),
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: "UPP Origen (Mapa)",
                        prefixIcon: const Icon(Icons.pin, color: Colors.grey),
                        filled: true, fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: _uppsDisponibles.map((upp) => DropdownMenuItem(value: upp, child: Text(upp))).toList(),
                      onChanged: (val) => setState(() => _uppSeleccionada = val),
                    ),

                  const SizedBox(height: 15),
                  _campoTexto("Destino (Rastro/Engorda)", Icons.local_shipping_outlined, TextInputType.text, _destinoController),
                  const SizedBox(height: 15),
                  
                  // Campo de Fecha conectado al Calendario
                  TextField(
                    controller: _fechaController,
                    readOnly: true, // Evita que se escriba con el teclado
                    onTap: () => _seleccionarFecha(context), // Abre el calendario
                    decoration: InputDecoration(
                      labelText: "Fecha de Salida",
                      prefixIcon: const Icon(Icons.calendar_today, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    ),
                  ),
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

            // --- BOTÓN FINALIZAR (CON ANIMACIÓN DE CARGA) ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: verdeVenta,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                onPressed: _estaGuardando ? null : _guardarVenta, // Si está guardando, se bloquea
                icon: _estaGuardando 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
                label: Text(
                  _estaGuardando ? "PROCESANDO..." : "FINALIZAR VENTA", 
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const VistaReporteLotes()));
                },
                icon: Icon(Icons.pie_chart_outline, color: verdeVenta),
                label: Text("VER REPORTE DE LOTES", style: TextStyle(color: verdeVenta, fontWeight: FontWeight.bold, fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: verdeVenta, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------
  // FUNCIONES DE AYUDA VISUAL
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

  Widget _campoTexto(String label, IconData icono, TextInputType tipo, TextEditingController controlador, {Function(String)? alCambiar}) {
    return TextField(
      controller: controlador,
      keyboardType: tipo,
      onChanged: alCambiar, 
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