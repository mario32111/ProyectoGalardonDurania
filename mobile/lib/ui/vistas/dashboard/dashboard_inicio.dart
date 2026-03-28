import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- AGREGADO PARA FILTRADO Y UID
import 'id_digital.dart';

class VistaDashboardInicio extends StatefulWidget {
  const VistaDashboardInicio({super.key});

  @override
  State<VistaDashboardInicio> createState() => _VistaDashboardInicioState();
}

class _VistaDashboardInicioState extends State<VistaDashboardInicio> {
  bool _estaCargando = true;

  String _totalCabezas = "0";
  String _alertasStock = "0";
  String _ventasMes = "\$0.00";

  List<Map<String, dynamic>> _listaAlertas = [];
  int _diaGraficaSeleccionado = 3; 

  @override
  void initState() {
    super.initState();
    _cargarDatosDeLaNube(); 
  }

  // ==============================================================================
  //  MOTOR DE EXTRACCIÓN DE DATOS REALES
  // ==============================================================================
  Future<void> _cargarDatosDeLaNube() async {
    int contadorCabezas = 0;
    double sumaVentas = 0.0;
    int contadorAlertasCriticas = 0;
    List<Map<String, dynamic>> alertasReales = [];

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      var ganadoObtenido = await FirebaseFirestore.instance.collection('ganado')
          .where('usuario_id', isEqualTo: user.uid).get();
      contadorCabezas = ganadoObtenido.docs.length;

      var ventasObtenidas = await FirebaseFirestore.instance.collection('ventas_salidas')
          .where('usuario_id', isEqualTo: user.uid).get();
      for (var doc in ventasObtenidas.docs) {
        sumaVentas += (doc.data()['monto_total'] ?? 0.0);
      }

      var inventarioObtenido = await FirebaseFirestore.instance.collection('inventario')
          .where('usuario_id', isEqualTo: user.uid).get();
      for (var doc in inventarioObtenido.docs) {
        var datos = doc.data();
        String nombreInsumo = datos['nombre'] ?? 'Producto Desconocido';
        double actual = (datos['cantidad_actual'] ?? 0).toDouble();
        double maxima = (datos['capacidad_maxima'] ?? 100).toDouble();
        String unidad = datos['unidad'] ?? 'Und';
        
        if (maxima <= 0) maxima = 1; 
        double porcentaje = actual / maxima;

        if (actual <= 0) {
          contadorAlertasCriticas++;
          alertasReales.add({
            "titulo": nombreInsumo,
            "mensaje": "¡TOTALMENTE AGOTADO! (0 $unidad)",
            "tipo": "critico"
          });
        } else if (porcentaje <= 0.20) {
          contadorAlertasCriticas++;
          alertasReales.add({
            "titulo": nombreInsumo,
            "mensaje": "Nivel muy bajo, quedan solo ${actual.toInt()} $unidad",
            "tipo": "critico"
          });
        } else if (porcentaje <= 0.50) {
          alertasReales.add({
            "titulo": nombreInsumo,
            "mensaje": "Nivel medio al ${(porcentaje * 100).toInt()}%",
            "tipo": "advertencia"
          });
        }
      }

      // ==========================================
      // ALERTAS REALES DESDE FIRESTORE (Notificaciones Push)
      // ==========================================
      // Nota: Esto se complementará con el StreamBuilder en el UI
      // para que sea tiempo real sin necesidad de recargar el dashboard.
      
      if (mounted) {
        setState(() {
          _totalCabezas = contadorCabezas.toString();
          _ventasMes = "\$${sumaVentas.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}";
          _alertasStock = contadorAlertasCriticas.toString();
          // _listaAlertas se manejará vía Stream ahora
          _estaCargando = false;
        });
      }
    } catch (e) {
      debugPrint("Error al cargar dashboard: $e");
      if (mounted) {
        setState(() => _estaCargando = false);
      }
    }
  }

  /// Formatea una fecha ISO 8601 a un texto relativo ("Hace 5 min", "Hace 2h", etc.)
  String _tiempoRelativo(String? fechaISO) {
    if (fechaISO == null) return '';
    try {
      final fecha = DateTime.parse(fechaISO);
      final ahora = DateTime.now();
      final diff = ahora.difference(fecha);

      if (diff.inSeconds < 60) return 'Hace un momento';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
      if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    } catch (_) {
      return '';
    }
  }

  void _mostrarNotificaciones(BuildContext context, Color colorTema) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4, 
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Row(
                children: [
                  Icon(Icons.notifications_active_rounded, color: colorTema),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text("Centro de Alertas", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                  // Botón: Marcar todas como leídas
                  IconButton(
                    tooltip: 'Marcar todas como leídas',
                    onPressed: () async {
                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;
                      
                      final batch = FirebaseFirestore.instance.batch();
                      final unread = await FirebaseFirestore.instance.collection('notificaciones')
                          .where('usuario_id', isEqualTo: user.uid)
                          .where('leido', isEqualTo: false)
                          .get();
                      
                      if (unread.docs.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("No tienes notificaciones pendientes"), duration: Duration(seconds: 1))
                        );
                        return;
                      }

                      for (var doc in unread.docs) {
                        batch.update(doc.reference, {'leido': true});
                      }
                      await batch.commit();
                      
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text("✅ Marcadas como leídas"), backgroundColor: colorTema, duration: const Duration(seconds: 1))
                        );
                      }
                    },
                    icon: Icon(Icons.done_all_rounded, color: colorTema, size: 22),
                  ),
                  // Botón: Borrar todas las notificaciones
                  IconButton(
                    tooltip: 'Borrar todas',
                    onPressed: () async {
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text("¿Borrar todas las notificaciones?"),
                          content: const Text("Esta acción no puede deshacerse. Se eliminarán todas las alertas de tu historial."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true), 
                              child: const Text("Borrar Todas", style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirmar != true) return;

                      final user = FirebaseAuth.instance.currentUser;
                      if (user == null) return;

                      final allDocs = await FirebaseFirestore.instance.collection('notificaciones')
                          .where('usuario_id', isEqualTo: user.uid)
                          .get();
                      
                      final batch = FirebaseFirestore.instance.batch();
                      for (var doc in allDocs.docs) {
                        batch.delete(doc.reference);
                      }
                      await batch.commit();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("🗑️ Todas las notificaciones eliminadas"), backgroundColor: Colors.red, duration: Duration(seconds: 2))
                        );
                      }
                    },
                    icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 22),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('notificaciones')
                    .where('usuario_id', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    .orderBy('fecha', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    print("❌ Error en Notificaciones: ${snapshot.error}");
                    return Center(child: Text("Error: ${snapshot.error}"));
                  }
                  
                  final docs = snapshot.data?.docs ?? [];
                  
                  if (snapshot.connectionState == ConnectionState.waiting && docs.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, color: Colors.grey, size: 40),
                          SizedBox(height: 10),
                          Text("No tienes notificaciones registradas", style: TextStyle(color: Colors.grey)),
                        ],
                      )
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final docSnapshot = docs[index];
                      final alerta = docSnapshot.data() as Map<String, dynamic>;
                      Color col;
                      IconData ico;
                      switch(alerta['tipo']) {
                        case 'critico': col = Colors.red; ico = Icons.error_outline; break;
                        case 'advertencia': col = Colors.orange; ico = Icons.warning_amber_rounded; break;
                        case 'info': col = Colors.green; ico = Icons.info_outline; break;
                        default: col = Colors.blue; ico = Icons.notifications_none;
                      }
                      bool unread = alerta['leido'] == false;
                      String tiempo = _tiempoRelativo(alerta['fecha']);

                      return Dismissible(
                        key: Key(docSnapshot.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 28),
                        ),
                        confirmDismiss: (direction) async {
                          return true; // Se elimina directamente al deslizar
                        },
                        onDismissed: (direction) async {
                          // Eliminar de Firestore
                          await FirebaseFirestore.instance.collection('notificaciones').doc(docSnapshot.id).delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("🗑️ \"${alerta['titulo']}\" eliminada"),
                              duration: const Duration(seconds: 2),
                              backgroundColor: Colors.grey[800],
                            ),
                          );
                        },
                        child: Opacity(
                          opacity: unread ? 1.0 : 0.6,
                          child: Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            color: col.withOpacity(unread ? 0.1 : 0.03),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                              side: BorderSide(color: col.withOpacity(unread ? 0.3 : 0.1)),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: col.withOpacity(unread ? 0.2 : 0.1),
                                child: Icon(ico, color: col),
                              ),
                              title: Text(
                                alerta['titulo'] ?? 'Sin título', 
                                style: TextStyle(
                                  fontWeight: unread ? FontWeight.bold : FontWeight.normal,
                                  color: unread ? Colors.black87 : Colors.grey[600],
                                )
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alerta['mensaje'] ?? '',
                                    style: TextStyle(color: unread ? Colors.black54 : Colors.grey[500]),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tiempo,
                                    style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                              trailing: unread 
                                ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle))
                                : null,
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================================
  // FUNCIÓN PARA ABRIR FORMULARIOS RÁPIDOS 
  // ==============================================================================
  void _abrirAccionRapida(String titulo, IconData icono, Color color, String coleccionBD, String nombreCampo, {bool esNumero = false}) {
    TextEditingController inputController = TextEditingController();
    bool guardando = false;
    bool archivoAdjunto = false;

    showModalBottomSheet(
      context: context,
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
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                          child: Icon(icono, color: color, size: 28),
                        ),
                        const SizedBox(width: 15),
                        Expanded(child: Text(titulo, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color))),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(modalContext)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    const Text("Complete la información para registrar en el sistema", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    
                    TextField(
                      controller: inputController,
                      keyboardType: esNumero ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
                      decoration: InputDecoration(
                        hintText: esNumero ? "Ej. 15000.50" : "Ej. Identificador o descripción...",
                        filled: true,
                        fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: Icon(Icons.edit, color: Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(height: 15),

                    InkWell(
                      onTap: () {
                        setModalState(() {
                          archivoAdjunto = !archivoAdjunto; 
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
                        decoration: BoxDecoration(
                          color: archivoAdjunto ? Colors.green.withOpacity(0.1) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: archivoAdjunto ? Colors.green : Colors.transparent),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              archivoAdjunto ? Icons.image : Icons.attach_file, 
                              color: archivoAdjunto ? Colors.green : Colors.grey[600]
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                archivoAdjunto ? "Evidencia_fotografica.jpg" : "Adjuntar foto o ticket (Opcional)", 
                                style: TextStyle(
                                  color: archivoAdjunto ? Colors.green[700] : Colors.grey[600], 
                                  fontWeight: archivoAdjunto ? FontWeight.bold : FontWeight.normal
                                )
                              )
                            ),
                            if (archivoAdjunto)
                              const Icon(Icons.check_circle, color: Colors.green, size: 20),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: guardando ? null : () async {
                          if (inputController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El campo no puede estar vacío'), backgroundColor: Colors.red));
                            return;
                          }

                          setModalState(() { guardando = true; });

                          try {
                            dynamic valorAGuardar = inputController.text.trim();
                            if (esNumero) {
                              valorAGuardar = double.tryParse(valorAGuardar) ?? 0.0;
                            }

                            final user = FirebaseAuth.instance.currentUser;
                            await FirebaseFirestore.instance.collection(coleccionBD).add({
                              'usuario_id': user?.uid ?? 'anonimo',
                              nombreCampo: valorAGuardar,
                              'fecha_registro': FieldValue.serverTimestamp(),
                              'origen': 'Acceso Rápido Dashboard',
                              'tiene_evidencia': archivoAdjunto 
                            });

                            if (mounted) {
                              Navigator.pop(modalContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('¡Registro guardado en la nube!'), backgroundColor: Colors.green)
                              );
                              _cargarDatosDeLaNube();
                            }
                          } catch (e) {
                            setModalState(() { guardando = false; });
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                          }
                        },
                        child: guardando 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("GUARDAR REGISTRO", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],
                ),
              )
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color azulAgro = const Color(0xFF01579B);
    final Color verdeVenta = const Color(0xFF2E7D32);

    return LayoutBuilder(
      builder: (context, constraints) {
        bool esMovil = constraints.maxWidth < 650;
        bool esTablet = constraints.maxWidth >= 650 && constraints.maxWidth < 1100;
        bool esEscritorio = constraints.maxWidth >= 1100;

        if (_estaCargando) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: azulAgro),
                const SizedBox(height: 15),
                const Text("Calculando inventario y ganado...", style: TextStyle(color: Colors.grey)),
              ],
            )
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: RefreshIndicator(
            onRefresh: _cargarDatosDeLaNube, 
            color: azulAgro,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(esMovil ? 20 : 35), 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Resumen General", style: TextStyle(fontSize: esMovil ? 24 : 32, fontWeight: FontWeight.w900, color: const Color(0xFF263238))),
                          const Text("Rancho en Guadalupe Victoria", style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                      if (esMovil)
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('notificaciones')
                              .where('usuario_id', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                              .where('leido', isEqualTo: false)
                              .snapshots(),
                          builder: (context, snapshot) {
                            bool tienePendientes = (snapshot.data?.docs.isNotEmpty ?? false);
                            return Stack(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.notifications_none_rounded, size: 28, color: Colors.black87),
                                  onPressed: () => _mostrarNotificaciones(context, azulAgro),
                                ),
                                if (tienePendientes)
                                  Positioned(
                                    right: 8,
                                    top: 8,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                      constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                                    ),
                                  )
                              ],
                            );
                          }
                        )
                      else
                        WidgetAnimacionHover(scale: 1.05, child: _widgetClima()),
                    ],
                  ),
                  
                  const SizedBox(height: 30),

                  if (esMovil) ...[
                    WidgetAnimacionHover(scale: 1.05, child: _widgetClima()),
                    const SizedBox(height: 25),
                  ],

                  // --- TARJETAS KPI (Layout Adaptado) ---
                  if (esMovil)
                    Row(
                      children: [
                        Expanded(child: WidgetAnimacionHover(scale: 1.05, child: _miniKpiCard("Ganado", _totalCabezas, Icons.grass, azulAgro))),
                        const SizedBox(width: 8),
                        Expanded(child: WidgetAnimacionHover(scale: 1.05, child: _miniKpiCard("Alertas", _alertasStock, Icons.warning_amber_rounded, int.parse(_alertasStock) > 0 ? Colors.red : Colors.orange))),
                        const SizedBox(width: 8),
                        Expanded(child: WidgetAnimacionHover(scale: 1.05, child: _miniKpiCard("Ventas", _ventasMes, Icons.attach_money, verdeVenta))),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: WidgetAnimacionHover(scale: 1.03, child: _kpiCard("Total Cabezas", _totalCabezas, Icons.grass, azulAgro))),
                        const SizedBox(width: 20),
                        Expanded(child: WidgetAnimacionHover(scale: 1.03, child: _kpiCard("Alertas Stock", _alertasStock, Icons.warning_amber_rounded, int.parse(_alertasStock) > 0 ? Colors.red : Colors.orange))),
                        const SizedBox(width: 20),
                        Expanded(child: WidgetAnimacionHover(scale: 1.03, child: _kpiCard("Ventas Acumuladas", _ventasMes, Icons.attach_money, verdeVenta))),
                      ],
                    ),

                  const SizedBox(height: 40), // Un poco más de espacio antes del título

                  // --- ACCESOS RÁPIDOS ---
                  const Text("Accesos Rápidos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 20), // Un poco más de espacio antes de los botones
                  _seccionAccesosRapidos(azulAgro), 

                  const SizedBox(height: 40), // Un poco más de espacio después de los botones

                  // --- ALERTAS REALES Y GRÁFICA ---
                  if (esMovil)
                    Column(
                      children: [
                        _seccionGraficaInteractiva(), 
                      ],
                    )
                  else if (esTablet)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 1, child: _seccionAlertas(azulAgro)),
                        const SizedBox(width: 20),
                        Expanded(flex: 1, child: _seccionGraficaInteractiva()), 
                      ],
                    )
                  else // esEscritorio
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 1, child: _seccionAlertas(azulAgro)),
                        const SizedBox(width: 25),
                        Expanded(flex: 2, child: _seccionGraficaInteractiva()), 
                      ],
                    ),
                    
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        );
      }
    );
  }

  // ==========================================
  // WIDGETS COMPONENTES 
  // ==========================================

  Widget _kpiCard(String titulo, String valor, IconData icono, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Revisando detalles de $titulo...'), duration: const Duration(seconds: 1))
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: color, width: 5)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icono, color: color, size: 30),
                  Icon(Icons.touch_app, color: Colors.grey[200], size: 20), 
                ],
              ),
              const SizedBox(height: 15),
              FittedBox( 
                fit: BoxFit.scaleDown,
                child: Text(valor, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              Text(titulo, style: TextStyle(fontSize: 14, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniKpiCard(String titulo, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, color: color, size: 22),
          const SizedBox(height: 6),
          FittedBox(child: Text(valor, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          Text(titulo, style: TextStyle(fontSize: 11, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _widgetClimaMini() {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.wb_sunny, color: Colors.yellow, size: 24),
          SizedBox(height: 8),
          Text("28°C", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          Text("Soleado", style: TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _widgetClima() {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Actualizando clima local...'), backgroundColor: Colors.blue, duration: Duration(seconds: 1))
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.wb_sunny, color: Colors.yellow, size: 30),
            SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("28°C Soleado", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text("Humedad: 40%", style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _seccionAccesosRapidos(Color colorTema) {
    final bool esMovil = MediaQuery.of(context).size.width < 650;
    
    if (esMovil) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
        children: [
          _botonRapidoMini(Icons.add_circle, "Animal", colorTema, 
            () => _abrirAccionRapida("Registrar Nuevo Animal", Icons.pets, colorTema, "ganado", "identificador_arete")),
          _botonRapidoMini(Icons.local_hospital, "Salud", Colors.redAccent, 
            () => _abrirAccionRapida("Reporte Veterinario", Icons.medical_services, Colors.redAccent, "reportes_salud", "descripcion_sintomas")),
          _botonRapidoMini(Icons.attach_money, "Venta", Colors.green, 
            () => _abrirAccionRapida("Nueva Venta Rápida", Icons.point_of_sale, Colors.green, "ventas_salidas", "monto_total", esNumero: true)),
          _botonRapidoMini(Icons.inventory, "Insumos", Colors.orange, 
            () => _abrirAccionRapida("Solicitar Alimento", Icons.local_shipping, Colors.orange, "pedidos_inventario", "insumo_solicitado")),
          _botonRapidoMini(Icons.badge, "Mi ID", Colors.blueGrey, 
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VistaIdDigital()))),
        ],
      );
    }

    return Wrap(
      spacing: 35,
      runSpacing: 25,
      alignment: WrapAlignment.spaceEvenly,
      children: [
        WidgetAnimacionHover(
          scale: 1.1,
          child: _botonRapido(Icons.add_circle_outline, "Nuevo\nAnimal", colorTema, 
            () => _abrirAccionRapida("Registrar Nuevo Animal", Icons.pets, colorTema, "ganado", "identificador_arete")),
        ),
        WidgetAnimacionHover(
          scale: 1.1,
          child: _botonRapido(Icons.local_hospital_outlined, "Reportar\nEnfermedad", Colors.redAccent, 
            () => _abrirAccionRapida("Reporte Veterinario", Icons.medical_services, Colors.redAccent, "reportes_salud", "descripcion_sintomas")),
        ),
        WidgetAnimacionHover(
          scale: 1.1,
          child: _botonRapido(Icons.attach_money, "Registrar\nVenta", Colors.green, 
            () => _abrirAccionRapida("Nueva Venta Rápida", Icons.point_of_sale, Colors.green, "ventas_salidas", "monto_total", esNumero: true)),
        ),
        WidgetAnimacionHover(
          scale: 1.1,
          child: _botonRapido(Icons.inventory_2_outlined, "Pedir\nInsumos", Colors.orange, 
            () => _abrirAccionRapida("Solicitar Alimento", Icons.local_shipping, Colors.orange, "pedidos_inventario", "insumo_solicitado")),
        ),
        WidgetAnimacionHover(
          scale: 1.1,
          child: _botonRapido(Icons.badge_outlined, "ID\nDigital", Colors.blueGrey, 
            () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VistaIdDigital()))),
        ),
      ],
    );
  }

  Widget _botonRapidoMini(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12), 
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 10),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _botonRapido(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        splashColor: color.withOpacity(0.2),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18), // Un poquito más grandes los círculos para que destaquen
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
                ),
                child: Icon(icon, color: color, size: 30), // Icono ligeramente más grande
              ),
              const SizedBox(height: 10),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seccionGraficaInteractiva() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Producción", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Icon(Icons.bar_chart, color: Colors.grey[400]),
            ],
          ),
          const Text("Pasa el cursor o toca para ver detalles", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _barraGrafica("Lun", 0.6, 0),
                _barraGrafica("Mar", 0.8, 1),
                _barraGrafica("Mie", 0.7, 2),
                _barraGrafica("Jue", 0.9, 3),
                _barraGrafica("Vie", 0.5, 4),
                _barraGrafica("Sab", 0.6, 5),
                _barraGrafica("Dom", 0.4, 6),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _barraGrafica(String dia, double porcentaje, int index) {
    bool activo = _diaGraficaSeleccionado == index;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _diaGraficaSeleccionado = index),
      child: GestureDetector(
        onTap: () => setState(() => _diaGraficaSeleccionado = index), 
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (activo)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text("${(porcentaje * 100).toInt()}%", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF01579B))),
              ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: activo ? 24 : 20, 
              height: activo ? (100 * porcentaje) + 10 : 100 * porcentaje, 
              decoration: BoxDecoration(
                color: activo ? const Color(0xFF01579B) : Colors.grey[200],
                borderRadius: BorderRadius.circular(5),
                boxShadow: activo ? [BoxShadow(color: const Color(0xFF01579B).withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : [],
              ),
            ),
            const SizedBox(height: 8),
            Text(dia, style: TextStyle(fontSize: 12, fontWeight: activo ? FontWeight.bold : FontWeight.normal, color: activo ? Colors.black : Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _seccionAlertas(Color colorTema) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("⚠️ Alertas y Notificaciones", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Divider(height: 20),
          ..._listaAlertas.map((alerta) {
            Color colorAlerta;
            switch (alerta['tipo']) {
              case 'critico': colorAlerta = Colors.red; break;
              case 'advertencia': colorAlerta = Colors.orange; break;
              case 'info': colorAlerta = Colors.green; break;
              default: colorAlerta = colorTema;
            }
            return WidgetAnimacionHover( 
              scale: 1.02,
              child: _alertaItem(alerta['titulo'], alerta['mensaje'], colorAlerta)
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _alertaItem(String titulo, String mensaje, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(mensaje, style: TextStyle(fontSize: 12, color: color == Colors.red ? Colors.red[700] : Colors.grey[600], fontWeight: color == Colors.red ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// ==============================================================================
// WIDGET EXTRA PARA CREAR EFECTO "HOVER" AUTOMÁTICO EN WEB/PC
// ==============================================================================
class WidgetAnimacionHover extends StatefulWidget {
  final Widget child;
  final double scale; 

  const WidgetAnimacionHover({Key? key, required this.child, this.scale = 1.05}) : super(key: key);

  @override
  State<WidgetAnimacionHover> createState() => _WidgetAnimacionHoverState();
}

class _WidgetAnimacionHoverState extends State<WidgetAnimacionHover> {
  bool _estaHover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _estaHover = true),
      onExit: (_) => setState(() => _estaHover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(_estaHover ? widget.scale : 1.0),
        child: widget.child,
      ),
    );
  }
}