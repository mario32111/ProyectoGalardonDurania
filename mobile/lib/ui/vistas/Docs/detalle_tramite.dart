import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class VistaDetalleTramite extends StatefulWidget {
  final Map<String, dynamic> tramite;
  final String tramiteId;

  const VistaDetalleTramite({
    super.key, 
    required this.tramite, 
    required this.tramiteId
  });

  @override
  State<VistaDetalleTramite> createState() => _VistaDetalleTramiteState();
}

class _VistaDetalleTramiteState extends State<VistaDetalleTramite> {
  late Map<String, dynamic> _tramiteActual;
  bool _subiendo = false;
  final Color azulAgro = const Color(0xFF01579B);
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tramiteActual = Map.from(widget.tramite);
  }

  // Función para refrescar datos desde Firestore
  Future<void> _refrescarDatos() async {
    final doc = await FirebaseFirestore.instance.collection('tramites').doc(widget.tramiteId).get();
    if (doc.exists && mounted) {
      setState(() {
        _tramiteActual = doc.data()!;
      });
    }
  }

  Future<void> _subirDocumentoDirecto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image == null) return;

    setState(() => _subiendo = true);

    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      var request = http.MultipartRequest('POST', Uri.parse('http://192.168.1.72:3000/upload'));
      request.headers['Authorization'] = 'Bearer $token';
      request.fields['tramite_id'] = widget.tramiteId;
      request.fields['folder'] = 'documentos_directos';
      
      request.files.add(await http.MultipartFile.fromPath('file', image.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Documento subido con éxito"), backgroundColor: Colors.green));
        await _refrescarDatos();
      } else {
        throw Exception("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al subir: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var estilo = _obtenerEstiloEstado(_tramiteActual['estado'] ?? 'PENDIENTE');
    Color colorEstado = estilo['color'];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("Gestión de Expediente", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: azulAgro,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(colorEstado, estilo['icono']),
                const SizedBox(height: 25),
                _buildSectionTitle("Observaciones"),
                const SizedBox(height: 10),
                _buildObservacionesList(),
                const SizedBox(height: 25),
                _buildSectionTitle("Seguimiento"),
                const SizedBox(height: 10),
                _buildTimelineHistorial(),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionTitle("Documentos Adjuntos"),
                    TextButton.icon(
                      onPressed: _subiendo ? null : _subirDocumentoDirecto,
                      icon: const Icon(Icons.add_a_photo, size: 18),
                      label: const Text("Adjuntar"),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                _buildDocumentosVisuales(),
                const SizedBox(height: 50),
              ],
            ),
          ),
          if (_subiendo)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            )
        ],
      ),
    );
  }

  Widget _buildDocumentosVisuales() {
    List<dynamic> docs = _tramiteActual['documentos'] ?? [];
    if (docs.isEmpty) return _emptyCard("No se han adjuntado documentos.");

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: docs.length,
      itemBuilder: (context, index) {
        var doc = docs[index];
        String url = doc['url'] ?? '';
        // Detección más flexible de imágenes para Firebase Storage
        bool esImagen = url.toLowerCase().contains('.jpg') || 
                        url.toLowerCase().contains('.jpeg') || 
                        url.toLowerCase().contains('.png') || 
                        url.toLowerCase().contains('alt=media');

        return InkWell(
          onTap: () => esImagen ? _mostrarImagenCompleta(url) : null,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: esImagen 
                      ? Hero(
                          tag: url,
                          child: Image.network(url, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _errorIcon())
                        )
                      : Container(color: Colors.grey[100], child: const Center(child: Icon(Icons.picture_as_pdf, size: 40, color: Colors.blueGrey))),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc['nombre'] ?? doc['nombre_documento'] ?? 'Archivo', 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87), 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 10, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(child: Text(doc['responsable'] ?? 'Sistema', style: const TextStyle(fontSize: 9, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _mostrarImagenCompleta(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Hero(tag: url, child: Image.network(url, fit: BoxFit.contain)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorIcon() => Container(color: Colors.grey[100], child: const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)));

  // --- MÉTODOS DE APOYO (Mantener lógica de diseño) ---
  Map<String, dynamic> _obtenerEstiloEstado(String estado) {
    switch (estado.toUpperCase()) {
      case 'PENDIENTE': return {'color': Colors.orange, 'icono': Icons.hourglass_empty};
      case 'EN_PROCESO': return {'color': Colors.blue, 'icono': Icons.sync};
      case 'COMPLETADO': return {'color': Colors.green, 'icono': Icons.check_circle_outline};
      case 'CANCELADO': return {'color': Colors.red, 'icono': Icons.error_outline};
      default: return {'color': Colors.grey, 'icono': Icons.help_outline};
    }
  }

  String _formatearFecha(dynamic fecha) {
    if (fecha == null) return '---';
    try {
      if (fecha is String) {
        DateTime dt = DateTime.parse(fecha);
        return DateFormat('dd/MM/yyyy HH:mm').format(dt);
      }
      return fecha.toString();
    } catch (e) {
      return fecha.toString();
    }
  }

  Widget _buildHeaderCard(Color colorEstado, IconData icono) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: colorEstado.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Icon(icono, size: 16, color: colorEstado),
                    const SizedBox(width: 6),
                    Text((_tramiteActual['estado'] ?? 'PENDIENTE').toString().toUpperCase(), style: TextStyle(color: colorEstado, fontWeight: FontWeight.bold, fontSize: 11)),
                  ],
                ),
              ),
              Text(_formatearFecha(_tramiteActual['fecha_solicitud']), style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 15),
          Text(_tramiteActual['numero_tramite'] ?? 'SIN FOLIO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: azulAgro)),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _infoCol("Etapa Actual", "${_tramiteActual['etapa_actual'] ?? 1}"),
              _infoCol("Tipo", _tramiteActual['tipo'] ?? 'General'),
            ],
          )
        ],
      ),
    );
  }

  Widget _infoCol(String label, String value) {
    return Column(children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)), const SizedBox(height: 4), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]);
  }

  Widget _buildSectionTitle(String titulo) {
    return Text(titulo.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey[600], letterSpacing: 1.1));
  }

  Widget _buildObservacionesList() {
    List<dynamic> obs = _tramiteActual['observaciones_list'] ?? [];
    if (obs.isEmpty) return _emptyCard("No hay comentarios.");
    return Column(children: obs.map((o) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(o['autor'] ?? 'Sistema', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12)), Text(_formatearFecha(o['fecha']), style: const TextStyle(color: Colors.grey, fontSize: 9))]), const SizedBox(height: 4), Text(o['texto'] ?? '', style: const TextStyle(fontSize: 13))]))).toList());
  }

  Widget _buildTimelineHistorial() {
    List<dynamic> historial = _tramiteActual['historial'] ?? [];
    if (historial.isEmpty) return _emptyCard("Sin historial.");
    return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)), child: Column(children: List.generate(historial.length, (index) {
          var h = historial[index];
          return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Column(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: azulAgro, shape: BoxShape.circle)), if (index != historial.length - 1) Expanded(child: Container(width: 1, color: Colors.grey[200]))]), const SizedBox(width: 12), Expanded(child: Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(h['nombre'] ?? 'Etapa', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), Text(_formatearFecha(h['fecha_inicio']), style: const TextStyle(color: Colors.grey, fontSize: 9))])))]));
        })));
  }

  Widget _emptyCard(String texto) => Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(texto, style: TextStyle(color: Colors.grey[400], fontSize: 12, fontStyle: FontStyle.italic))));
}
