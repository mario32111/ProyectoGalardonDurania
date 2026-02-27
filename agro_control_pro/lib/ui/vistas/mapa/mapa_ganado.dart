import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // El motor del mapa gratis
import 'package:latlong2/latlong.dart'; // Para las coordenadas

class MapaGanado extends StatefulWidget {
  const MapaGanado({super.key});

  @override
  State<MapaGanado> createState() => _MapaGanadoState();
}

class _MapaGanadoState extends State<MapaGanado> {
  // Controlador para mover el mapa si lo necesitamos
  final MapController _mapController = MapController();

  // Aquí guardamos los puntos que tocas
  List<LatLng> _puntosPoligono = [];

  // Coordenada inicial (La puse en Durango, pero puedes cambiarla)
  final LatLng _centroInicial = const LatLng(24.0277, -104.6532);

  // Función al tocar el mapa
  void _onTapMapa(TapPosition tapPosition, LatLng punto) {
    setState(() {
      _puntosPoligono.add(punto);
    });
  }

  // Borrar el último punto si te equivocas
  void _deshacerUltimoPunto() {
    if (_puntosPoligono.isNotEmpty) {
      setState(() {
        _puntosPoligono.removeLast();
      });
    }
  }

  // Simulación de guardar
  void _guardarZona() {
    if (_puntosPoligono.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marca al menos 3 puntos para cerrar el corral.')),
      );
      return;
    }
    // AQUÍ ES DONDE MANDARÍAS LOS DATOS A TU BASE DE DATOS
    print("Guardando coordenadas: $_puntosPoligono");
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Zona guardada (Sistema OpenSource)'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Definir Potrero'),
        backgroundColor: Colors.green[800],
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () {
              setState(() {
                _puntosPoligono.clear();
              });
            },
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centroInicial, // Centro inicial
              initialZoom: 15.0, // Zoom
              onTap: _onTapMapa, // Detectar toques
            ),
            children: [
              // CAPA 1: IMAGEN SATELITAL (ESRI WORLD IMAGERY - GRATIS)
              TileLayer(
                urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                userAgentPackageName: 'com.agro.control',
              ),

              // CAPA 2: DIBUJO DEL POLÍGONO (EL ÁREA VERDE)
              PolygonLayer(
                polygons: [
                  if (_puntosPoligono.isNotEmpty)
                    Polygon(
                      points: _puntosPoligono,
                      color: const Color(0xFF4CAF50).withOpacity(0.3), // Relleno verde transparente
                      borderColor: Colors.white, // Borde blanco
                      borderStrokeWidth: 3,
                      isFilled: true,
                    ),
                ],
              ),

              // CAPA 3: LOS PUNTOS BLANCOS EN LAS ESQUINAS
              MarkerLayer(
                markers: _puntosPoligono.map((punto) {
                  return Marker(
                    point: punto,
                    width: 20,
                    height: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),

          // --- BOTONES FLOTANTES DE ABAJO ---
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Botón Deshacer
                  IconButton(
                    icon: const Icon(Icons.undo, color: Colors.red),
                    onPressed: _puntosPoligono.isEmpty ? null : _deshacerUltimoPunto,
                    tooltip: "Deshacer punto",
                  ),
                  
                  // Texto informativo
                  Text(
                    "${_puntosPoligono.length} Puntos",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),

                  // Botón Guardar
                  ElevatedButton.icon(
                    onPressed: _guardarZona,
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
        ],
      ),
    );
  }
}