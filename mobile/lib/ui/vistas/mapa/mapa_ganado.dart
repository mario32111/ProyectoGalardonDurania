import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- AGREGADO PARA FIREBASE
import 'package:firebase_auth/firebase_auth.dart';     // <--- AGREGADO PARA UID
class MapaGanado extends StatefulWidget {
  const MapaGanado({super.key});

  @override
  State<MapaGanado> createState() => _MapaGanadoState();
}

class _MapaGanadoState extends State<MapaGanado> {
  final MapController _mapController = MapController();
  List<LatLng> _puntosPoligono = [];
  
  final LatLng _centroInicial = const LatLng(24.0277, -104.6532); // Durango
  final List<Map<String, dynamic>> _zonasGuardadas = [];

  // --- NUEVA VARIABLE: Controla el modo de dibujo ---
  bool _modoRectangulo = false; 
  bool _esSatelital = true; // <--- Controla la capa del mapa (Satelital vs 2D)
  bool _estaCargando = true; // <--- Nuevo: Estado de carga

  @override
  void initState() {
    super.initState();
    _cargarZonasDesdeFirebase();
  }

  // ==============================================================================
  // CARGA DE DATOS DESDE FIREBASE
  // ==============================================================================
  Future<void> _cargarZonasDesdeFirebase() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('zonas_mapa')
          .where('usuario_id', isEqualTo: user.uid)
          .get();

      final List<Map<String, dynamic>> zonasCargadas = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final List<dynamic> puntosRaw = data['puntos'] ?? [];
        
        // Convertimos los puntos de Map {lat, lng} a objetos LatLng
        final List<LatLng> puntosConvertidos = puntosRaw.map((p) {
          return LatLng(p['lat'].toDouble(), p['lng'].toDouble());
        }).toList();

        zonasCargadas.add({
          'id': doc.id,
          'nombre': data['nombre'],
          'upp': data['upp'] ?? 'N/A', // <--- LEER UPP
          'tipo': data['tipo'],
          'detalles': data['detalles'],
          'puntos': puntosConvertidos,
          'color': _obtenerColorPorTipo(data['tipo']),
        });
      }

      if (mounted) {
        setState(() {
          _zonasGuardadas.clear();
          _zonasGuardadas.addAll(zonasCargadas);
          _estaCargando = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando zonas: $e");
      if (mounted) setState(() => _estaCargando = false);
    }
  }  // ==============================================================================
  // LÓGICA DE DIBUJO INTELIGENTE (Libre vs Rectángulo)
  // ==============================================================================
  void _onTapMapa(TapPosition tapPosition, LatLng punto) {
    setState(() {
      if (_modoRectangulo) {
        // --- MODO RECTÁNGULO / CUADRADO ---
        if (_puntosPoligono.isEmpty) {
          // 1er toque: Guarda la primera esquina
          _puntosPoligono.add(punto);
        } else if (_puntosPoligono.length == 1) {
          // 2do toque: Calcula automáticamente las 4 esquinas del cuadrado
          LatLng p1 = _puntosPoligono[0];
          LatLng p2 = punto; // Esquina opuesta
          
          _puntosPoligono.clear();
          _puntosPoligono.add(p1); // Esquina 1
          _puntosPoligono.add(LatLng(p1.latitude, p2.longitude)); // Esquina 2 (calculada)
          _puntosPoligono.add(p2); // Esquina 3 (el punto que tocaste)
          _puntosPoligono.add(LatLng(p2.latitude, p1.longitude)); // Esquina 4 (calculada)
        } else {
          // Si ya hay un cuadrado y tocas de nuevo, reinicia el dibujo
          _puntosPoligono.clear();
          _puntosPoligono.add(punto);
        }
      } else {
        // --- MODO POLÍGONO LIBRE (Punto por punto) ---
        _puntosPoligono.add(punto);
      }
    });
  }

  void _deshacerUltimoPunto() {
    if (_puntosPoligono.isNotEmpty) {
      setState(() {
        if (_modoRectangulo && _puntosPoligono.length == 4) {
          // Si es un rectángulo completo, deshacer borra todo para volver a trazar
          _puntosPoligono.clear();
        } else {
          _puntosPoligono.removeLast();
        }
      });
    }
  }

  // ==============================================================================
  // CONTROLES DE ZOOM MANUALES
  // ==============================================================================
  void _zoomIn() {
    final zoomActual = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, zoomActual + 1);
  }

  void _zoomOut() {
    final zoomActual = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, zoomActual - 1);
  }

  // ==============================================================================
  // FORMULARIO MODAL DE GUARDADO (Intacto)
  // ==============================================================================
  void _mostrarFormularioGuardar() {
    // Si es modo rectángulo, requiere 4 puntos; si es libre, al menos 3.
    if (_puntosPoligono.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Termina de trazar el área primero.'), backgroundColor: Colors.orange),
      );
      return;
    }

    TextEditingController nombreController = TextEditingController();
    TextEditingController uppController = TextEditingController(); // <--- CONTROLADOR UPP
    String tipoSeleccionado = 'Corral'; 
    String detallesAdicionales = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        bool guardando = false; 

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
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
                        const Text("Registrar Nueva Zona", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                        IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                      ],
                    ),
                    const SizedBox(height: 15),

                    const Text("Nombre del Área", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nombreController,
                      decoration: InputDecoration(
                        hintText: "Ej. Potrero Norte, Corral de Engorda...",
                        filled: true, fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.edit_location_alt, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text("Identificador UPP", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: uppController,
                      decoration: InputDecoration(
                        hintText: "Ej. 10-092-001-001",
                        filled: true, fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.pin, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text("Tipo de Instalación", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: tipoSeleccionado,
                      decoration: InputDecoration(
                        filled: true, fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        prefixIcon: const Icon(Icons.category, color: Colors.grey),
                      ),
                      items: ['Corral', 'Pastizal', 'Bodega', 'Bebedero', 'Cuarentena', 'Otro']
                          .map((tipo) => DropdownMenuItem(value: tipo, child: Text(tipo)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => tipoSeleccionado = val);
                      },
                    ),
                    const SizedBox(height: 20),
                    
                     const Text("Detalles (Capacidad, estado, etc.)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (val) => detallesAdicionales = val,
                      decoration: InputDecoration(
                        hintText: "Ej. Capacidad max: 50 cabezas. Pasto Bermuda.",
                        filled: true, fillColor: Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[800],
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          if (nombreController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, ingresa un nombre.'), backgroundColor: Colors.red));
                            return;
                          }

                          setModalState(() {
                            guardando = true;
                          });

                          try {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null) return;

                            // Preparamos los puntos para Firestore (lista de mapas)
                            final puntosParaFirebase = _puntosPoligono.map((p) => {
                              'lat': p.latitude,
                              'lng': p.longitude,
                            }).toList();

                            // GUARDAMOS EN FIREBASE
                            final docRef = await FirebaseFirestore.instance.collection('zonas_mapa').add({
                              'usuario_id': user.uid,
                              'nombre': nombreController.text.trim(),
                              'upp': uppController.text.trim(), // <--- GUARDAR UPP
                              'tipo': tipoSeleccionado,
                              'detalles': detallesAdicionales,
                              'puntos': puntosParaFirebase,
                              'fecha_creacion': FieldValue.serverTimestamp(),
                            });

                            if (mounted) {
                              setState(() {
                                _zonasGuardadas.add({
                                  'id': docRef.id,
                                  'nombre': nombreController.text,
                                  'upp': uppController.text.trim(), // <--- LOCAL UPP
                                  'tipo': tipoSeleccionado,
                                  'detalles': detallesAdicionales,
                                  'puntos': List<LatLng>.from(_puntosPoligono), 
                                  'color': _obtenerColorPorTipo(tipoSeleccionado),
                                });
                                _puntosPoligono.clear();
                              });
                            }

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zona guardada en la nube.'), backgroundColor: Colors.green));
                          } catch (e) {
                            setModalState(() => guardando = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
                          }
                        },
                        child: guardando 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("GUARDAR EN EL MAPA", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 25),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }

  Color _obtenerColorPorTipo(String tipo) {
    switch (tipo) {
      case 'Corral': return Colors.orange;
      case 'Pastizal': return Colors.lightGreen;
      case 'Bodega': return Colors.brown;
      case 'Bebedero': return Colors.blue;
      case 'Cuarentena': return Colors.red;
      default: return Colors.purple;
    }
  }

  void _mostrarInfoZona(Map<String, dynamic> zona) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.location_on, color: zona['color']),
            const SizedBox(width: 10),
            Expanded(child: Text(zona['nombre'], style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("UPP: ${zona['upp']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 5),
            Text("Tipo: ${zona['tipo']}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Detalles: ${zona['detalles'].isNotEmpty ? zona['detalles'] : 'Ninguno.'}"),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("CERRAR")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Polygon> todosLosPoligonos = [];

    for (var zona in _zonasGuardadas) {
      todosLosPoligonos.add(
        Polygon(
          points: zona['puntos'],
          color: (zona['color'] as Color).withOpacity(0.4),
          borderColor: zona['color'],
          borderStrokeWidth: 3,
          isFilled: true,
        ),
      );
    }

    if (_puntosPoligono.isNotEmpty) {
      todosLosPoligonos.add(
        Polygon(
          points: _puntosPoligono,
          color: const Color(0xFF4CAF50).withOpacity(0.3),
          borderColor: Colors.white,
          borderStrokeWidth: 3,
          isFilled: true,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa del Rancho', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green[800],
        foregroundColor: Colors.white,
        actions: [
          if (_estaCargando)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
            ),
          if (_puntosPoligono.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: "Borrar dibujo actual",
              onPressed: () => setState(() => _puntosPoligono.clear()),
            )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centroInicial, 
              initialZoom: 15.0, 
              onTap: _onTapMapa, 
              // interactionOptions: const InteractionOptions(flags: InteractiveFlag.all), // Asegura zoom táctil
            ),
            children: [
              TileLayer(
                urlTemplate: _esSatelital 
                  ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                  : 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: _esSatelital ? const [] : const ['a', 'b', 'c'],
                userAgentPackageName: 'com.agro.control',
              ),

              PolygonLayer(polygons: todosLosPoligonos),

              MarkerLayer(
                markers: [
                  ..._puntosPoligono.map((punto) {
                    return Marker(
                      point: punto,
                      width: 15, height: 15,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                      ),
                    );
                  }).toList(),

                  ..._zonasGuardadas.map((zona) {
                    LatLng puntoCentral = zona['puntos'][0]; 
                    return Marker(
                      point: puntoCentral,
                      width: 40, height: 40,
                      child: GestureDetector(
                        onTap: () => _mostrarInfoZona(zona),
                        child: Icon(Icons.location_on, color: zona['color'], size: 40),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),

          // --- BOTONES FLOTANTES DE ZOOM (A LA DERECHA) ---
          Positioned(
            right: 20,
            bottom: 120, // Arriba del panel de dibujo
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "btnZoomIn",
                  backgroundColor: Colors.white,
                  onPressed: _zoomIn,
                  child: const Icon(Icons.add, color: Colors.black87),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: "btnZoomOut",
                  backgroundColor: Colors.white,
                  onPressed: _zoomOut,
                  child: const Icon(Icons.remove, color: Colors.black87),
                ),
              ],
            ),
          ),

          // --- BOTÓN TIPO DE MAPA (ESTILO GOOGLE MAPS - ARRIBA IZQUIERDA) ---
          Positioned(
            left: 20,
            top: 90, // <--- Movido arriba para evitar solapamiento con instrucciones
            child: GestureDetector(
              onTap: () => setState(() => _esSatelital = !_esSatelital),
              child: Container(
                width: 65,
                height: 65,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8)],
                  image: DecorationImage(
                    image: NetworkImage(
                      _esSatelital 
                        ? 'https://tile.openstreetmap.org/15/8800/12500.png' // Miniatura 2D
                        : 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/15/12500/8800' // Miniatura Satelital
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Container(
                  alignment: Alignment.bottomCenter,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      _esSatelital ? "2D" : "Satélite", 
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
              ),
            ),
          ),

          // --- SELECTOR DE HERRAMIENTA (ARRIBA) ---
          Positioned(
            top: 20, left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)]
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Herramienta:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                  const SizedBox(width: 15),
                  ChoiceChip(
                    label: const Text("Libre"),
                    selected: !_modoRectangulo,
                    onSelected: (val) => setState(() {
                      _modoRectangulo = false;
                      _puntosPoligono.clear(); // Limpia al cambiar de modo
                    }),
                    selectedColor: Colors.green[100],
                    avatar: const Icon(Icons.gesture, size: 18),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Text("Cuadrado"),
                    selected: _modoRectangulo,
                    onSelected: (val) => setState(() {
                      _modoRectangulo = true;
                      _puntosPoligono.clear(); // Limpia al cambiar de modo
                    }),
                    selectedColor: Colors.green[100],
                    avatar: const Icon(Icons.crop_square, size: 18),
                  ),
                ],
              ),
            ),
          ),

          // --- PANEL DE EDICIÓN FLOTANTE (ABAJO) ---
          if (_puntosPoligono.isNotEmpty)
            Positioned(
              bottom: 30, left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.undo, color: Colors.red),
                      onPressed: _deshacerUltimoPunto,
                      tooltip: "Deshacer",
                    ),
                    Text(
                      _modoRectangulo && _puntosPoligono.length < 4
                        ? "Toca la esquina opuesta" 
                        : "Área lista",
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 14, 
                        color: _puntosPoligono.length >= 3 ? Colors.green[700] : Colors.black54
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _mostrarFormularioGuardar, 
                      icon: const Icon(Icons.save),
                      label: const Text("GUARDAR"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
           // Instrucciones iniciales
           if (_puntosPoligono.isEmpty && _zonasGuardadas.isEmpty)
              Positioned(
              bottom: 40, left: 40, right: 40,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    _modoRectangulo 
                      ? "Toca dos puntos opuestos para formar un rectángulo."
                      : "Toca el mapa libremente para trazar las esquinas del área.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}