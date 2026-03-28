import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _cargarReporte();
  }

  Future<void> _cargarReporte() async {
    final resp = await ReportesService().obtenerReporteLotes();
    
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
