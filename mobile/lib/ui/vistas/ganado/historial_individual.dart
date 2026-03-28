import 'package:flutter/material.dart';
import '../../../services/reportes_service.dart';
import '../../../services/export_service.dart';

class VistaHistorialIndividual extends StatefulWidget {
  const VistaHistorialIndividual({super.key});

  @override
  State<VistaHistorialIndividual> createState() => _VistaHistorialIndividualState();
}

class _VistaHistorialIndividualState extends State<VistaHistorialIndividual> {
  final TextEditingController _searchController = TextEditingController();
  final Color azulAgro = const Color(0xFF01579B);
  
  bool _isLoading = false;
  Map<String, dynamic>? _animalData;
  List _salud = [];
  List _eventos = [];
  List _monitoreo = [];

  Future<void> _buscarHistorial() async {
    final arete = _searchController.text.trim();
    if (arete.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor ingresa un arete SINIIGA')));
      return;
    }

    setState(() {
      _isLoading = true;
      _animalData = null;
      _salud = [];
      _eventos = [];
      _monitoreo = [];
    });

    final resp = await ReportesService().obtenerHistorialIndividual(arete);
    
    if (resp != null) {
      setState(() {
        _animalData = resp['animal'];
        _salud = resp['salud'] ?? [];
        _eventos = resp['eventos'] ?? [];
        _monitoreo = resp['monitoreo'] ?? [];
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se encontró información para este arete.')));
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _exportarPDF() async {
    if (_animalData == null) return;
    try {
      await ExportService.exportarHistorialIndividualPdf(_animalData!, _salud, _monitoreo, _eventos);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar PDF: $e')));
    }
  }

  void _exportarExcel() async {
    if (_animalData == null) return;
    try {
      await ExportService.exportarHistorialIndividualExcel(_animalData!, _salud, _monitoreo, _eventos);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al exportar Excel: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Historial Individual', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: azulAgro,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_animalData != null) ...[
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
      body: Column(
        children: [
          // Campo de búsqueda
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Arete SINIIGA',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onSubmitted: (_) => _buscarHistorial(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isLoading ? null : _buscarHistorial,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: azulAgro,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('BUSCAR', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _animalData == null
                ? const Center(child: Text("Busca un arete SINIIGA para ver su historial.", style: TextStyle(color: Colors.grey)))
                : _buildResultados(),
          )
        ],
      ),
    );
  }

  Widget _buildResultados() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tarjeta de Información General
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
                      Icon(Icons.pets, color: azulAgro, size: 30),
                      const SizedBox(width: 15),
                      Text("Información General", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: azulAgro)),
                    ],
                  ),
                  const Divider(height: 30),
                  _infoRow("Arete SINIIGA", _animalData!['arete_siniiga']?.toString() ?? 'N/A'),
                  _infoRow("Arete Interno", _animalData!['arete_interno']?.toString() ?? 'N/A'),
                  _infoRow("UPP Ubicación", _animalData!['upp']?.toString() ?? 'N/A'),
                  _infoRow("Peso Gral (KG)", _animalData!['peso_kg']?.toString() ?? 'N/A'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Historial de Salud
          const Text("Reportes de Salud", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (_salud.isEmpty)
            const Text("No hay reportes de salud registrados.", style: TextStyle(color: Colors.grey))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _salud.length,
              itemBuilder: (context, index) {
                final r = _salud[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.medical_services, color: Colors.white)),
                    title: Text(r['descripcion_sintomas'] ?? 'Reporte de salud'),
                    subtitle: Text('Fecha: ${_formatDate(r['fecha_registro'])}\nTratamiento: ${r['tratamiento'] ?? 'N/A'}'),
                    isThreeLine: true,
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          // Historial de Eventos Críticos (NUEVO)
          const Text("Eventos Críticos (Movilizaciones, Vacunas)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (_eventos.isEmpty)
            const Text("No hay eventos recientes.", style: TextStyle(color: Colors.grey))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _eventos.length,
              itemBuilder: (context, index) {
                final e = _eventos[index];
                IconData icono = Icons.event_note;
                if (e['tipo_evento'] == 'Vacunación') icono = Icons.vaccines;
                if (e['tipo_evento'] == 'Movilización') icono = Icons.local_shipping;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: Colors.orangeAccent, child: Icon(icono, color: Colors.white)),
                    title: Text(e['tipo_evento'] ?? 'Evento'),
                    subtitle: Text('Fecha: ${_formatDate(e['fecha_registro'])}\nObs: ${e['descripcion'] ?? 'N/A'}'),
                    isThreeLine: true,
                  ),
                );
              },
            ),

          const SizedBox(height: 20),

          // Historial de Monitoreo
          const Text("Última Telemetría Automática", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (_monitoreo.isEmpty)
            const Text("No hay datos de collares inteligentes recientes.", style: TextStyle(color: Colors.grey))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _monitoreo.length,
              itemBuilder: (context, index) {
                final m = _monitoreo[index];
                return ListTile(
                  leading: const Icon(Icons.satellite_alt, color: Colors.blueGrey),
                  title: Text('Temp: ${m['temperatura']} °C | Actividad: ${m['actividad'] ?? 'Normal'}'),
                  subtitle: Text(_formatDate(m['timestamp'])),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
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
