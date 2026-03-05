import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VistaStockAlimentos extends StatefulWidget {
  const VistaStockAlimentos({super.key});

  @override
  State<VistaStockAlimentos> createState() => _VistaStockAlimentosState();
}

class _VistaStockAlimentosState extends State<VistaStockAlimentos> {
  final Color naranjaInventario = const Color(0xFFEF6C00);
  String _textoBusqueda = "";

  // Lógica de iconos mejorada
  IconData _obtenerIcono(String nombre) {
    String n = nombre.toLowerCase();
    if (n.contains('maiz') || n.contains('grano') || n.contains('sorgo')) return Icons.grain;
    if (n.contains('alfalfa') || n.contains('pasto') || n.contains('paca')) return Icons.grass;
    if (n.contains('liq') || n.contains('agua') || n.contains('mela')) return Icons.water_drop;
    if (n.contains('sal') || n.contains('minera')) return Icons.eco;
    if (n.contains('vacu') || n.contains('medi') || n.contains('dosis')) return Icons.medication;
    return Icons.inventory_2; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Un gris más profesional y limpio
      body: Column(
        children: [
          // --- HEADER FIJO (No se oculta al hacer scroll) ---
          Container(
            padding: const EdgeInsets.only(top: 60, left: 25, right: 25, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: naranjaInventario.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(10)
                      ),
                      child: Icon(Icons.inventory_2, color: naranjaInventario, size: 30),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("CONTROL DE STOCK", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: naranjaInventario)),
                        const Text("Niveles de insumos en tiempo real", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // BARRA DE BÚSQUEDA REDISEÑADA
                TextField(
                  onChanged: (valor) => setState(() => _textoBusqueda = valor.toLowerCase()),
                  decoration: InputDecoration(
                    hintText: "Buscar insumo...",
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ],
            ),
          ),

          // --- LISTA DINÁMICA CONECTADA A FIREBASE ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('inventario').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error al cargar datos"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _pantallaVacia();
                }

                // Filtrado por texto de búsqueda
                var productos = snapshot.data!.docs.where((doc) {
                  var d = doc.data() as Map<String, dynamic>;
                  return (d['nombre'] ?? '').toString().toLowerCase().contains(_textoBusqueda);
                }).toList();

                if (productos.isEmpty) {
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text("No hay coincidencias con tu búsqueda.", style: TextStyle(color: Colors.grey)),
                  ));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(25),
                  itemCount: productos.length,
                  itemBuilder: (context, index) {
                    var datos = productos[index].data() as Map<String, dynamic>;
                    return _itemStock(
                      datos['nombre'] ?? 'Sin nombre',
                      _obtenerIcono(datos['nombre'] ?? ''),
                      (datos['cantidad_actual'] ?? 0).toDouble(),
                      (datos['capacidad_maxima'] ?? 1000).toDouble(),
                      datos['unidad'] ?? 'Und'
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- DISEÑO CUANDO EL INVENTARIO ESTÁ VACÍO ---
  Widget _pantallaVacia() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          Text(
            "Tu bodega está vacía.\nRegistra una compra para ver el stock.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  // --- TARJETA VISUAL DE CADA PRODUCTO ---
  Widget _itemStock(String nombre, IconData icono, double actual, double maximo, String unidad) {
    if (maximo <= 0) maximo = 1; 
    
    // Cálculo de porcentaje con límite del 100% para evitar errores visuales
    double porcentaje = (actual / maximo).clamp(0.0, 1.0);
    
    // Semáforo Inteligente
    Color colorBarra = Colors.green;
    String estado = "ÓPTIMO";
    if (porcentaje <= 0.50) { colorBarra = Colors.orange; estado = "MEDIO"; }
    if (porcentaje <= 0.20) { colorBarra = Colors.red; estado = "CRÍTICO"; }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          // Fila Superior
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                child: Icon(icono, color: Colors.blueGrey, size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 0.5)),
                    Text("$estado · Máx: ${maximo.toInt()} $unidad", style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Text("${(porcentaje * 100).toInt()}%", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colorBarra)),
            ],
          ),
          const SizedBox(height: 18),
          
          // BARRA DE PROGRESO ANIMADA Y CON DEGRADADO
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                height: 12,
                width: (MediaQuery.of(context).size.width - 90) * porcentaje,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [colorBarra, colorBarra.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: colorBarra.withOpacity(0.3), blurRadius: 5, offset: const Offset(0, 2))],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Fila Inferior
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Existencia actual:", style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
              Text("${actual.toInt()} $unidad", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: colorBarra)),
            ],
          )
        ],
      ),
    );
  }
}