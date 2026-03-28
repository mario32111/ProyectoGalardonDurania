import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/reportes_service.dart';
import '../../../services/export_service.dart';

class VistaReporteLotes extends StatefulWidget {
  const VistaReporteLotes({super.key});

  @override
  State<VistaReporteLotes> createState() => _VistaReporteLotesState();
}

class _VistaReporteLotesState extends State<VistaReporteLotes> {
  final Color azulAgro = const Color(0xFF01579B);
  
  bool _isLoading = true;
  Map<String, dynamic>? _resumen;
  List _compras = [];
  List _ventas = [];
  
  List<String> _upps = [];
  String? _selectedUpp;

  @override
  void initState() {
    super.initState();
    _cargarUpps().then((_) => _cargarReporte());
  }

  Future<void> _cargarUpps() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // Buscar UPPs en varias colecciones al mismo tiempo para no omitir ninguna
      final futures = await Future.wait([
        FirebaseFirestore.instance.collection('ganado').where('usuario_id', isEqualTo: user.uid).get(),
        FirebaseFirestore.instance.collection('compras_lotes').where('usuario_id', isEqualTo: user.uid).get(),
        FirebaseFirestore.instance.collection('ventas_salidas').where('usuario_id', isEqualTo: user.uid).get(),
        FirebaseFirestore.instance.collection('zonas_mapa').where('usuario_id', isEqualTo: user.uid).get(),
      ]);

      final Set<String> uppsSet = {};

      // Extraer de ganado
      for (var d in futures[0].docs) {
        final upp = d.data()['upp']?.toString();
        if (upp != null && upp.trim().isNotEmpty) uppsSet.add(upp.trim());
      }
      
      // Extraer de compras_lotes
      for (var d in futures[1].docs) {
        final upp = d.data()['upp_destino']?.toString();
        if (upp != null && upp.trim().isNotEmpty) uppsSet.add(upp.trim());
      }

      // Extraer de ventas_salidas
      for (var d in futures[2].docs) {
        final upp = d.data()['upp_origen']?.toString();
        if (upp != null && upp.trim().isNotEmpty) uppsSet.add(upp.trim());
      }

      // Extraer de zonas_mapa
      for (var d in futures[3].docs) {
        final upp = d.data()['upp']?.toString();
        if (upp != null && upp.trim().isNotEmpty) uppsSet.add(upp.trim());
      }
          
      if (mounted) {
        setState(() {
           _upps = uppsSet.toList();
           _upps.sort();
        });
      }
    } catch (e) {
      debugPrint("Error upps $e");
    }
  }

  Future<void> _cargarReporte() async {
    setState(() => _isLoading = true);
    final resp = await ReportesService().obtenerReporteLotes(upp: _selectedUpp);
    
    if (resp != null && mounted) {
      setState(() {
        _resumen = resp['resumen'];
        _compras = resp['compras_detalle'] ?? [];
        _ventas = resp['ventas_detalle'] ?? [];
      });
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _exportarPDF() async {
    if (_resumen == null) return;
    try {
      await ExportService.exportarReporteLotesPdf(_resumen!, _compras, _ventas);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar PDF: $e')));
    }
  }

  void _exportarExcel() async {
    if (_resumen == null) return;
    try {
      await ExportService.exportarReporteLotesExcel(_resumen!, _compras, _ventas);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar Excel: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Reporte de Lotes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: azulAgro,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_resumen != null) ...[
            IconButton(
              tooltip: 'Exportar a PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: _exportarPDF,
            ),
            IconButton(
              tooltip: 'Exportar a Excel',
              icon: const Icon(Icons.table_view),
              onPressed: _exportarExcel,
            ),
          ]
        ],
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: azulAgro))
        : _resumen == null 
          ? const Center(child: Text('Error al cargar reporte.'))
          : _buildContenido(),
    );
  }

  Widget _buildContenido() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtro de UPP
          if (_upps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedUpp,
                      hint: const Text("Filtro global: Todas las UPPs"),
                      items: [
                        const DropdownMenuItem(value: null, child: Text("Todas las UPPs")),
                        ..._upps.map((u) => DropdownMenuItem(value: u, child: Text("UPP: $u")))
                      ],
                      onChanged: (val) {
                        setState(() => _selectedUpp = val);
                        _cargarReporte();
                      },
                    ),
                  ),
                ),
              ),
            ),

          // SECCION SALUD (SOLO SI HAY UNA UPP SELECCIONADA)
          if (_selectedUpp != null && _resumen!['salud'] != null) ...[
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.health_and_safety, color: Colors.teal, size: 30),
                        const SizedBox(width: 15),
                        Text("Metría Clínica de Granja", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
                      ],
                    ),
                    const Divider(height: 30),
                    _infoRow("Vacas registradas (UPP)", _resumen!['salud']['total_vacas_upp']?.toString() ?? '0', Colors.black87),
                    _infoRow("Casos clínicos", _resumen!['salud']['vacas_con_historial_enfermo']?.toString() ?? '0', Colors.orange),
                    _infoRow("Porcentaje de afección", _resumen!['salud']['porcentaje_enfermas']?.toString() ?? '0%', Colors.red),
                    
                    if ((_resumen!['salud']['desglose_enfermedades'] as Map).isNotEmpty) ...[
                      const SizedBox(height: 15),
                      const Text("Distribución de patologías históricas:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 5),
                      ...(_resumen!['salud']['desglose_enfermedades'] as Map).entries.map((e) => 
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.circle, size: 8, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(child: Text("${e.key}", style: const TextStyle(fontSize: 12))),
                              Text("${e.value} casos", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        )
                      ).toList()
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],

          // SECCION TRAZABILIDAD (SOLO SI HAY UNA UPP SELECCIONADA)
          if (_selectedUpp != null && _resumen!['trazabilidad'] != null) ...[
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.timeline, color: azulAgro, size: 30),
                        const SizedBox(width: 15),
                        Text("Trazabilidad (Eventos Críticos)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: azulAgro)),
                      ],
                    ),
                    const Divider(height: 30),
                    _infoRow("Total intervenciones históricas", _resumen!['trazabilidad']['total_eventos_historicos']?.toString() ?? '0', Colors.black87),
                    
                    if ((_resumen!['trazabilidad']['desglose_tipos'] as Map).isNotEmpty) ...[
                      const SizedBox(height: 15),
                      const Text("Distribución por tipo de evento:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 5),
                      ...(_resumen!['trazabilidad']['desglose_tipos'] as Map).entries.map((e) => 
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline, size: 12, color: Colors.blueAccent),
                              const SizedBox(width: 8),
                              Expanded(child: Text("${e.key}", style: const TextStyle(fontSize: 12))),
                              Text("${e.value} registros", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        )
                      ).toList()
                    ],

                    if ((_resumen!['trazabilidad']['ultimas_5_intervenciones'] as List).isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text("Últimos registros relevantes (Top 5):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                      const SizedBox(height: 10),
                      ...(_resumen!['trazabilidad']['ultimas_5_intervenciones'] as List).map((e) => 
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.arrow_right_alt, size: 16, color: Colors.grey),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  "[${e['arete_siniiga']}] ${e['tipo_evento']}: ${e['descripcion']}",
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        )
                      ).toList()
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],

          // Tarjeta de Resumen Financiero
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: azulAgro, size: 30),
                      const SizedBox(width: 15),
                      Text("Resumen Financiero Global", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: azulAgro)),
                    ],
                  ),
                  const Divider(height: 30),
                  _infoRow("Cabezas Compradas", _resumen!['compras']['cabezas']?.toString() ?? '0', Colors.black87),
                  _infoRow("Inversión Gral", "\$${_resumen!['compras']['monto']}", Colors.redAccent),
                  const SizedBox(height: 10),
                  _infoRow("Cabezas Vendidas", _resumen!['ventas']['cabezas']?.toString() ?? '0', Colors.black87),
                  _infoRow("Ingresos Gral", "\$${_resumen!['ventas']['monto']}", Colors.green),
                  const Divider(height: 30),
                  _infoRow(
                    "Balance", 
                    "\$${_resumen!['balance']}", 
                    (_resumen!['balance'] ?? 0) >= 0 ? Colors.green : Colors.redAccent,
                    isBold: true
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),

          // Lista de Compras
          const Text("Historial de Compras (Lotes)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (_compras.isEmpty)
            const Text("No hay compras registradas.", style: TextStyle(color: Colors.grey))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _compras.length,
              itemBuilder: (context, index) {
                final c = _compras[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.arrow_downward, color: Colors.white)),
                    title: Text('${c['cantidad_cabezas']} cabezas de ${c['proveedor']}'),
                    subtitle: Text('Fecha: ${_formatDate(c['fecha_registro_sistema'] ?? c['fecha'])}\nTotal: \$${c['total_pagado']}'),
                    isThreeLine: true,
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          // Lista de Ventas
          const Text("Historial de Ventas (Salidas)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (_ventas.isEmpty)
            const Text("No hay ventas registradas.", style: TextStyle(color: Colors.grey))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ventas.length,
              itemBuilder: (context, index) {
                final v = _ventas[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.arrow_upward, color: Colors.white)),
                    title: Text('${v['cantidad_cabezas']} vendidas a ${v['cliente']}'),
                    subtitle: Text('Fecha: ${_formatDate(v['fecha_registro_sistema'] ?? v['fecha_salida'])}\nTotal: \$${v['monto_total']}'),
                    isThreeLine: true,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Text(
            value, 
            style: TextStyle(
              fontWeight: FontWeight.bold, 
              color: valueColor, 
              fontSize: isBold ? 18 : 14
            )
          ),
        ],
      ),
    );
  }

  String _formatDate(dynamic dateField) {
    if (dateField == null) return "N/A";
    
    if (dateField is Map && dateField['_seconds'] != null) {
      final dt = DateTime.fromMillisecondsSinceEpoch((dateField['_seconds'] as int) * 1000);
      return "${dt.day}/${dt.month}/${dt.year}";
    }
    
    if (dateField is String) {
      try {
        final dt = DateTime.parse(dateField);
        return "${dt.day}/${dt.month}/${dt.year}";
      } catch (_) {
        return dateField; 
      }
    }
    
    return dateField.toString();
  }
}
