import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'detalle_tramite.dart'; // <--- NUEVA PANTALLA DE DETALLE

const Map<String, Map<String, dynamic>> tramiteTypes = {
  'PRUEBAS_GANADO': {
    'nombre': 'Pruebas de Ganado',
    'etapas': [
      {'orden': 1, 'nombre': 'Solicitud Recibida'},
      {'orden': 2, 'nombre': 'Programación de Visita'},
      {'orden': 3, 'nombre': 'Toma de Muestras'},
      {'orden': 4, 'nombre': 'Muestras en Laboratorio'},
      {'orden': 5, 'nombre': 'Resultados Disponibles'},
      {'orden': 6, 'nombre': 'Finalizado'}
    ]
  },
  'MOVILIZACION': {
    'nombre': 'Trámite de Movilización',
    'etapas': [
      {'orden': 1, 'nombre': 'Solicitud Recibida'},
      {'orden': 2, 'nombre': 'Revisión Documental'},
      {'orden': 3, 'nombre': 'Inspección Sanitaria'},
      {'orden': 4, 'nombre': 'Aprobación Pendiente'},
      {'orden': 5, 'nombre': 'Guía Emitida'},
      {'orden': 6, 'nombre': 'Finalizado'}
    ]
  },
  'EXPORTACION': {
    'nombre': 'Trámite de Exportación',
    'etapas': [
      {'orden': 1, 'nombre': 'Solicitud Recibida'},
      {'orden': 2, 'nombre': 'Revisión Documental'},
      {'orden': 3, 'nombre': 'Certificaciones Sanitarias'},
      {'orden': 4, 'nombre': 'Inspección Aduanal'},
      {'orden': 5, 'nombre': 'Aprobación SENASA'},
      {'orden': 6, 'nombre': 'Documentación Lista'},
      {'orden': 7, 'nombre': 'Finalizado'}
    ]
  }
};

class VistaTramitesVentanilla extends StatefulWidget {
  const VistaTramitesVentanilla({super.key});

  @override
  State<VistaTramitesVentanilla> createState() => _VistaTramitesVentanillaState();
}

class _VistaTramitesVentanillaState extends State<VistaTramitesVentanilla> {
  final Color azulAgro = const Color(0xFF01579B);
  String _filtroActual = "Todos";

  // --- LÓGICA DE ESTILOS SEGÚN EL ESTADO DEL TRÁMITE ---
  Map<String, dynamic> _obtenerEstiloEstado(String estado) {
    switch (estado.toUpperCase()) {
      case 'PENDIENTE': return {'color': Colors.orange, 'icono': Icons.inbox};
      case 'EN_PROCESO': return {'color': Colors.blue, 'icono': Icons.autorenew};
      case 'COMPLETADO': return {'color': Colors.green, 'icono': Icons.check_circle};
      case 'CANCELADO': return {'color': Colors.red, 'icono': Icons.cancel};
      default: return {'color': Colors.grey, 'icono': Icons.help_outline};
    }
  }

  // ==========================================================
  // FORMULARIO VISUAL CONECTADO A FIREBASE
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
                    const Text("La solicitud se enviará a la asociación ganadera.", style: TextStyle(color: Colors.grey)),
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
                      items: tramiteTypes.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(entry.value['nombre']),
                        );
                      }).toList(),
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

                    // --- BOTÓN CONECTADO A FIREBASE ---
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

                          try {
                            String r = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();
                            String folioGenerado = 'TRM-2026-$r';
                            String dtIso = DateTime.now().toIso8601String();

                            // GUARDAMOS EN LA COLECCIÓN 'tramites' CON ESTRUCTURA DEL BACKEND
                            final user = FirebaseAuth.instance.currentUser;
                            await FirebaseFirestore.instance.collection('tramites').add({
                              'numero_tramite': folioGenerado,
                              'tipo': tipoSeleccionado,
                              'usuario_id': user?.uid ?? 'anonimo',
                              'ganado_ids': [],
                              'fecha_solicitud': dtIso,
                              'etapa_actual': 1,
                              'estado': 'PENDIENTE',
                              'observaciones': detallesController.text.isEmpty ? 'Solicitud enviada exitosamente.' : detallesController.text,
                              'documentos': [],
                              'historial': [{
                                'etapa': 1,
                                'nombre': 'Solicitud Recibida',
                                'fecha_inicio': dtIso,
                                'responsable': 'Aplicación Móvil',
                                'observaciones': 'Trámite creado desde la app'
                              }],
                              'observaciones_list': [],
                              'timestamp': FieldValue.serverTimestamp(),
                            });

                            if (mainContext.mounted) {
                              Navigator.pop(mainContext);
                              ScaffoldMessenger.of(mainContext).showSnackBar(const SnackBar(content: Text('¡Trámite enviado con éxito!'), backgroundColor: Colors.green));
                            }
                          } catch (e) {
                            setModalState(() { guardando = false; });
                            ScaffoldMessenger.of(mainContext).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                          }
                        },
                        child: guardando 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("ENVIAR SOLICITUD", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(right: 75.0),
        child: FloatingActionButton.extended(
          backgroundColor: azulAgro,
          onPressed: () => _mostrarFormularioNuevoTramite(context),
          icon: const Icon(Icons.note_add, color: Colors.white),
          label: const Text("Nuevo Trámite", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
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

            // --- FILTROS ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filtroChip("Todos"),
                  const SizedBox(width: 10),
                  _filtroChip("Pendiente"),
                  const SizedBox(width: 10),
                  _filtroChip("En Proceso"),
                  const SizedBox(width: 10),
                  _filtroChip("Finalizado"),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- LECTOR DE FIREBASE EN TIEMPO REAL ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // FILTRADO MULTI-TENANT: Solo cargar los trámites del usuario actual
                // ORDENAMIENTO: Usar fecha_solicitud (ISO String) que es consistente con el backend
                stream: FirebaseFirestore.instance
                    .collection('tramites')
                    .where('usuario_id', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? 'anonimo')
                    .orderBy('fecha_solicitud', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open, size: 80, color: Colors.grey[300]),
                          const SizedBox(height: 15),
                          Text("No has solicitado ningún trámite.", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                        ],
                      ),
                    );
                  }

                  // Extraemos los datos e inyectamos el ID del documento
                  var todosLosTramites = snapshot.data!.docs.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id; // <--- Importante para identificar el trámite
                    return data;
                  }).toList();
                  
                  List<Map<String, dynamic>> tramitesFiltrados = todosLosTramites.where((tramite) {
                    String estado = (tramite['estado'] ?? '').toString().toUpperCase();
                    if (_filtroActual == "Pendiente") return estado == 'PENDIENTE';
                    if (_filtroActual == "En Proceso") return estado == 'EN_PROCESO';
                    if (_filtroActual == "Finalizado") return estado == 'COMPLETADO' || estado == 'CANCELADO';
                    return true;
                  }).toList();

                  if (tramitesFiltrados.isEmpty) {
                    return Center(child: Text("No hay trámites en esta categoría.", style: TextStyle(color: Colors.grey[500])));
                  }

                  return ListView.builder(
                    itemCount: tramitesFiltrados.length,
                    itemBuilder: (context, index) {
                      final t = tramitesFiltrados[index];
                      return _tarjetaTramite(context, t);
                    },
                  );
                },
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
  // WIDGET DE LA BARRA DE SEGUIMIENTO (Línea de tiempo dinámica)
  // ==========================================================
  Widget _construirBarraProgreso(String tipo, int etapaActual) {
    var info = tramiteTypes[tipo];
    if (info == null) return const SizedBox();

    List<dynamic> etapas = info['etapas'];
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(etapas.length * 2 - 1, (index) {
            if (index % 2 == 0) {
              int pasoIndex = index ~/ 2;
              var etapa = etapas[pasoIndex];
              return _construirPasoIndicador(etapa['nombre'], etapa['orden'], etapaActual);
            } else {
              int pasoIndex = index ~/ 2;
              return _construirLinea(etapas[pasoIndex]['orden'], etapaActual);
            }
          }),
        ),
      ),
    );
  }

  Widget _construirPasoIndicador(String titulo, int indicePaso, int pasoActual) {
    bool completado = indicePaso <= pasoActual;
    bool actual = indicePaso == pasoActual;
    
    Color colorPaso = completado ? azulAgro : Colors.grey[300]!;

    return SizedBox(
      width: 70,
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
                ? const Icon(Icons.check, size: 14, color: Colors.white) 
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
    return Container(
      width: 30,
      height: 2,
      color: completado ? azulAgro : Colors.grey[200],
      margin: const EdgeInsets.only(bottom: 20, left: 5, right: 5), 
    );
  }

  // ==========================================================
  // WIDGET DE LA TARJETA PRINCIPAL
  // ==========================================================
  Widget _tarjetaTramite(BuildContext context, Map<String, dynamic> datos) {
    String idTramite = datos['id'] ?? '---';
    String estado = datos['estado'] ?? 'PENDIENTE';
    var estilo = _obtenerEstiloEstado(estado);
    
    Color colorEstado = estilo['color'];
    IconData iconoEstado = estilo['icono'];
    
    String tipo = datos['tipo'] ?? '';
    String tituloTipo = tramiteTypes[tipo]?['nombre'] ?? 'Desconocido';
    int etapaActual = datos['etapa_actual'] ?? 1;

    String fechaVisual = "";
    if (datos['fecha_solicitud'] != null) {
      fechaVisual = datos['fecha_solicitud'].toString().split('T').first;
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (c) => VistaDetalleTramite(tramite: datos, tramiteId: idTramite))
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(tituloTipo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87), overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: Text("Folio: ${datos['numero_tramite'] ?? '---'}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700], fontSize: 12)),
              )
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [const Icon(Icons.calendar_today, size: 14, color: Colors.grey), const SizedBox(width: 5), Text("Iniciado el: $fechaVisual", style: const TextStyle(color: Colors.grey, fontSize: 13))]),
          
          const Divider(height: 20),
          _construirBarraProgreso(tipo, etapaActual),
          const Divider(height: 20),

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
    ),
  );
}
}