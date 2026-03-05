import 'package:flutter/material.dart';

class VistaTramitesVentanilla extends StatefulWidget {
  const VistaTramitesVentanilla({super.key});

  @override
  State<VistaTramitesVentanilla> createState() => _VistaTramitesVentanillaState();
}

class _VistaTramitesVentanillaState extends State<VistaTramitesVentanilla> {
  final Color azulAgro = const Color(0xFF01579B);
  String _filtroActual = "Todos";

  // Lista de datos simulados 
  List<Map<String, dynamic>> _tramitesSimulados = [
    {
      'folio': 'TRM-849302',
      'tipo_tramite': 'Actualización de UPP',
      'fecha_solicitud': '03/03/2026',
      'estado': 'En revisión',
      'observaciones': 'Documentos en proceso de validación por el técnico.'
    },
    {
      'folio': 'TRM-102938',
      'tipo_tramite': 'Guía de Tránsito',
      'fecha_solicitud': '28/02/2026',
      'estado': 'Listo para recoger',
      'observaciones': 'Pase a ventanilla 2 con su identificación.'
    },
    {
      'folio': 'TRM-552199',
      'tipo_tramite': 'Alta de Aretes SINIIGA',
      'fecha_solicitud': '04/03/2026',
      'estado': 'Requiere corrección',
      'observaciones': 'Falta la copia de la INE del propietario. Favor de adjuntar.'
    }
  ];

  Map<String, dynamic> _obtenerEstiloEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'recibido en ventanilla': return {'color': Colors.orange, 'icono': Icons.inbox, 'paso': 0};
      case 'en revisión': return {'color': Colors.blue, 'icono': Icons.search, 'paso': 1};
      case 'requiere corrección': return {'color': Colors.red, 'icono': Icons.error_outline, 'paso': 2};
      case 'aprobado': return {'color': Colors.green, 'icono': Icons.check_circle_outline, 'paso': 2};
      case 'listo para recoger': return {'color': Colors.green, 'icono': Icons.check_circle, 'paso': 3};
      default: return {'color': Colors.grey, 'icono': Icons.help_outline, 'paso': 0};
    }
  }

  // ==========================================================
  // FORMULARIO VISUAL DE SOLICITUD
  // ==========================================================
  void _mostrarFormularioNuevoTramite(BuildContext mainContext) {
    String? tipoSeleccionado;
    TextEditingController detallesController = TextEditingController();
    bool guardando = false;

    showModalBottomSheet(
      context: mainContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext modalContext, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
                top: 25, left: 25, right: 25
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Solicitar Trámite", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: azulAgro)),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalContext)),
                      ],
                    ),
                    const Text("Módulo Frontend - Diseño de Interfaz", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 25),

                    const Text("¿Qué documento necesitas?", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        filled: true, fillColor: const Color(0xFFF8FAFC),
                        prefixIcon: const Icon(Icons.document_scanner, color: Colors.grey),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      hint: const Text("Selecciona una opción"),
                      items: [
                        "Guía de Tránsito (Movilización)",
                        "Alta de Aretes SINIIGA",
                        "Actualización de UPP",
                        "Constancia de Productor",
                        "Otro documento"
                      ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) {
                        setModalState(() {
                          tipoSeleccionado = val;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 20),

                    const Text("Detalles adicionales", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: detallesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Ej. Solicito guía para mover 15 becerros...",
                        filled: true, fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: azulAgro,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: guardando ? null : () async {
                          if (tipoSeleccionado == null) {
                            ScaffoldMessenger.of(mainContext).showSnackBar(const SnackBar(content: Text('Por favor elige un tipo de trámite'), backgroundColor: Colors.red));
                            return;
                          }

                          setModalState(() {
                            guardando = true;
                          });

                          // Simulación de carga (Fake Backend delay)
                          await Future.delayed(const Duration(seconds: 2));

                          if (!mainContext.mounted) return;

                          // Agregamos el trámite a la lista visual
                          setState(() {
                            _tramitesSimulados.insert(0, {
                              'folio': 'TRM-NUEVO',
                              'tipo_tramite': tipoSeleccionado ?? 'Trámite',
                              'fecha_solicitud': '05/03/2026',
                              'estado': 'Recibido en ventanilla', // Siempre inicia aquí
                              'observaciones': detallesController.text.isEmpty ? 'Solicitud enviada a la asociación.' : detallesController.text,
                            });
                          });
                          
                          Navigator.pop(mainContext);
                          ScaffoldMessenger.of(mainContext).showSnackBar(const SnackBar(content: Text('¡UI Actualizada!'), backgroundColor: Colors.green));
                        },
                        child: guardando 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("SIMULAR ENVÍO", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> tramitesFiltrados = _tramitesSimulados.where((tramite) {
      String estado = (tramite['estado'] ?? '').toString().toLowerCase();
      if (_filtroActual == "En Proceso") return estado != 'listo para recoger' && estado != 'aprobado';
      if (_filtroActual == "Listos para Recoger") return estado == 'listo para recoger' || estado == 'aprobado';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: azulAgro,
        onPressed: () => _mostrarFormularioNuevoTramite(context),
        icon: const Icon(Icons.note_add, color: Colors.white),
        label: const Text("Nuevo Trámite", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),

      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: azulAgro.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.folder_shared, color: azulAgro, size: 32),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("VENTANILLA DIGITAL", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: azulAgro)),
                    const Text("Seguimiento de trámites en tiempo real", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 25),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filtroChip("Todos"),
                  const SizedBox(width: 10),
                  _filtroChip("En Proceso"),
                  const SizedBox(width: 10),
                  _filtroChip("Listos para Recoger"),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: tramitesFiltrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 15),
                          Text("No hay trámites en esta categoría.", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: tramitesFiltrados.length,
                      itemBuilder: (context, index) => _tarjetaTramite(tramitesFiltrados[index]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtroChip(String titulo) {
    bool activo = _filtroActual == titulo;
    return ChoiceChip(
      label: Text(titulo, style: TextStyle(color: activo ? Colors.white : Colors.black87, fontWeight: activo ? FontWeight.bold : FontWeight.normal)),
      selected: activo,
      selectedColor: azulAgro,
      backgroundColor: Colors.white,
      onSelected: (bool seleccionado) {
        setState(() {
          _filtroActual = titulo;
        });
      },
    );
  }

  // ==========================================================
  // WIDGET DE LA BARRA DE SEGUIMIENTO (Línea de tiempo)
  // ==========================================================
  Widget _construirBarraSeguimiento(int pasoActual, bool esError) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Row(
        children: [
          _construirPasoIndicador("Recibido", 0, pasoActual, esError),
          _construirLinea(0, pasoActual),
          _construirPasoIndicador("Revisión", 1, pasoActual, esError),
          _construirLinea(1, pasoActual),
          _construirPasoIndicador(esError ? "Corrección" : "Aprobado", 2, pasoActual, esError),
          _construirLinea(2, pasoActual),
          _construirPasoIndicador("Listo", 3, pasoActual, esError),
        ],
      ),
    );
  }

  Widget _construirPasoIndicador(String titulo, int indicePaso, int pasoActual, bool esError) {
    bool completado = indicePaso <= pasoActual;
    bool actual = indicePaso == pasoActual;
    
    // Si hay un error y estamos en ese paso, se pinta rojo. Si no, azul o gris.
    Color colorPaso = completado 
        ? (esError && actual ? Colors.red : azulAgro) 
        : Colors.grey[300]!;

    return Expanded(
      flex: 2,
      child: Column(
        children: [
          Container(
            height: 24,
            width: 24,
            decoration: BoxDecoration(
              color: completado ? colorPaso : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: completado ? colorPaso : Colors.grey[300]!, width: 2)
            ),
            child: completado 
                ? Icon(esError && actual ? Icons.close : Icons.check, size: 14, color: Colors.white) 
                : null,
          ),
          const SizedBox(height: 5),
          Text(
            titulo, 
            style: TextStyle(
              fontSize: 10, 
              color: actual ? Colors.black87 : Colors.grey, 
              fontWeight: actual ? FontWeight.bold : FontWeight.normal
            ), 
            textAlign: TextAlign.center, 
            overflow: TextOverflow.visible
          )
        ],
      ),
    );
  }

  Widget _construirLinea(int indicePaso, int pasoActual) {
    bool completado = indicePaso < pasoActual;
    return Expanded(
      flex: 3,
      child: Container(
        height: 2,
        color: completado ? azulAgro : Colors.grey[200],
        margin: const EdgeInsets.only(bottom: 20), // Para alinearlo con los círculos
      ),
    );
  }

  // ==========================================================
  // WIDGET DE LA TARJETA PRINCIPAL
  // ==========================================================
  Widget _tarjetaTramite(Map<String, dynamic> datos) {
    String estado = datos['estado'] ?? 'Desconocido';
    var estilo = _obtenerEstiloEstado(estado);
    
    Color colorEstado = estilo['color'];
    IconData iconoEstado = estilo['icono'];
    int pasoActual = estilo['paso'];
    bool esError = estado.toLowerCase() == 'requiere corrección';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: colorEstado, width: 6)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título y Folio
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(datos['tipo_tramite'] ?? 'Trámite', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87), overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: Text("Folio: ${datos['folio'] ?? '---'}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [const Icon(Icons.calendar_today, size: 14, color: Colors.grey), const SizedBox(width: 5), Text("Iniciado el: ${datos['fecha_solicitud']}", style: const TextStyle(color: Colors.grey, fontSize: 13))]),
          
          const Divider(height: 20),

          // --- AQUÍ INSERTAMOS LA BARRA DE SEGUIMIENTO ---
          _construirBarraSeguimiento(pasoActual, esError),

          const Divider(height: 20),

          // Estado actual y Observaciones
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(iconoEstado, color: colorEstado, size: 28),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(estado.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, color: colorEstado, fontSize: 14)),
                    const SizedBox(height: 5),
                    Text(datos['observaciones'] ?? 'Sin observaciones.', style: TextStyle(color: Colors.grey[600], fontSize: 13, height: 1.4)),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}