import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart'; 

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

  // ==============================================================================
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
    String tipoSeleccionado = 'Corral'; 
    String detallesAdicionales = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
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
                        onPressed: () {
                          if (nombreController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, ingresa un nombre.'), backgroundColor: Colors.red));
                            return;
                          }

                          setState(() {
                            _zonasGuardadas.add({
                              'nombre': nombreController.text,
                              'tipo': tipoSeleccionado,
                              'detalles': detallesAdicionales,
                              'puntos': List<LatLng>.from(_puntosPoligono), 
                              'color': _obtenerColorPorTipo(tipoSeleccionado),
                            });
                            _puntosPoligono.clear();
                          });

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zona registrada exitosamente.'), backgroundColor: Colors.green));
                        },
                        child: const Text("GUARDAR EN EL MAPA", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
                urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
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