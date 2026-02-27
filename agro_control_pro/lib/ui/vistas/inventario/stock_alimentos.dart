import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <--- Importamos Firebase

class VistaStockAlimentos extends StatefulWidget {
  const VistaStockAlimentos({super.key});

  @override
  State<VistaStockAlimentos> createState() => _VistaStockAlimentosState();
}

class _VistaStockAlimentosState extends State<VistaStockAlimentos> {
  final Color naranjaInventario = const Color(0xFFEF6C00);
  
  // Controlador para atrapar lo que escribes en la barra de búsqueda
  String _textoBusqueda = "";

  // Pequeña función para ponerle un icono bonito dependiendo del nombre del insumo
  IconData _obtenerIcono(String nombre) {
    String n = nombre.toLowerCase();
    if (n.contains('maiz') || n.contains('grano')) return Icons.grain;
    if (n.contains('alfalfa') || n.contains('pasto')) return Icons.grass;
    if (n.contains('liquido') || n.contains('agua') || n.contains('melaza')) return Icons.water_drop;
    if (n.contains('sal') || n.contains('mineral')) return Icons.eco;
    return Icons.inventory_2; // Icono por defecto de la caja
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: naranjaInventario.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.inventory_2, color: naranjaInventario, size: 32),
                ),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("CONTROL DE STOCK", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: naranjaInventario)),
                    const Text("Niveles de insumos en tiempo real", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 25),

            // --- BARRA DE BÚSQUEDA VIVA ---
            TextField(
              onChanged: (valor) {
                // Cada que escribes una letra, la pantalla se actualiza para filtrar
                setState(() {
                  _textoBusqueda = valor.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Buscar producto...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
            ),

            const SizedBox(height: 30),
            const Text("Almacén Principal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 15),

            // --- LISTA DE PRODUCTOS CONECTADA A FIREBASE (TIEMPO REAL) ---
            StreamBuilder<QuerySnapshot>(
              // Apuntamos a la colección 'inventario'
              stream: FirebaseFirestore.instance.collection('inventario').snapshots(),
              builder: (context, snapshot) {
                // 1. Mientras va a internet a buscar los datos
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 2. Si la base de datos está vacía (¡Como pasará ahorita!)
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text(
                        "Tu inventario está vacío.\nVe a 'Comprar Producto' para agregar insumos a tu bodega.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                    ),
                  );
                }

                // 3. Si hay datos, los filtramos con lo que escribiste en la búsqueda
                var productos = snapshot.data!.docs.where((doc) {
                  var datos = doc.data() as Map<String, dynamic>;
                  String nombre = (datos['nombre'] ?? '').toString().toLowerCase();
                  return nombre.contains(_textoBusqueda);
                }).toList();

                if (productos.isEmpty) {
                  return const Center(child: Text("No se encontraron productos con ese nombre."));
                }

                // 4. Dibujamos tus tarjetas bonitas con los datos de la nube
                return Column(
                  children: productos.map((documento) {
                    var datos = documento.data() as Map<String, dynamic>;
                    
                    return _itemStock(
                      datos['nombre'] ?? 'Sin nombre',
                      _obtenerIcono(datos['nombre'] ?? ''), // Le asigna icono automático
                      (datos['cantidad_actual'] ?? 0).toDouble(),
                      (datos['capacidad_maxima'] ?? 100).toDouble(), // Evita errores si no hay máximo
                      datos['unidad'] ?? 'Und'
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET PERSONALIZADO PARA CADA ITEM (INTACTO) ---
  Widget _itemStock(String nombre, IconData icono, double actual, double maximo, String unidad) {
    // Protección de seguridad por si el máximo llega en cero desde la base de datos
    if (maximo <= 0) maximo = 1; 

    // Cálculo del porcentaje (0.0 a 1.0)
    double porcentaje = actual / maximo;
    if (porcentaje > 1.0) porcentaje = 1.0; // Evita que la barra gráfica explote si te pasas del máximo
    
    // Lógica del Semáforo
    Color colorBarra = Colors.green;
    String estado = "Óptimo";
    
    if (porcentaje <= 0.50) {
      colorBarra = Colors.orange;
      estado = "Medio";
    }
    if (porcentaje <= 0.20) {
      colorBarra = Colors.red;
      estado = "Crítico";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Fila Superior: Icono y Nombre
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                child: Icon(icono, color: Colors.black54),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("$estado · Capacidad: ${maximo.toInt()} $unidad", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              // Porcentaje grande a la derecha
              Text(
                "${(porcentaje * 100).toInt()}%", 
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: colorBarra)
              ),
            ],
          ),
          
          const SizedBox(height: 15),

          // Barra de Progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: porcentaje,
              color: colorBarra,
              backgroundColor: Colors.grey[200],
              minHeight: 10,
            ),
          ),
          
          const SizedBox(height: 8),

          // Texto de cantidades debajo de la barra
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Disponible:", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text("${actual.toInt()} $unidad", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          )
        ],
      ),
    );
  }
}