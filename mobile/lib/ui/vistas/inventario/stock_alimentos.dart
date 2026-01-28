import 'package:flutter/material.dart';

class VistaStockAlimentos extends StatelessWidget {
  const VistaStockAlimentos({super.key});

  @override
  Widget build(BuildContext context) {
    final Color naranjaInventario = const Color(0xFFEF6C00);

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

            // --- BARRA DE BÚSQUEDA ---
            TextField(
              decoration: InputDecoration(
                hintText: "Buscar producto...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
            ),

            const SizedBox(height: 30),

            // --- LISTA DE PRODUCTOS (CARDS INTELIGENTES) ---
            const Text("Almacén Principal", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 15),

            // Item 1: Nivel Alto (Verde)
            _itemStock(
              "Maíz Rolado", 
              Icons.grain, 
              3800, 5000, "Kg" // Actual, Máximo, Unidad
            ),

            // Item 2: Nivel Medio (Naranja)
            _itemStock(
              "Alfalfa Pacas", 
              Icons.grass, 
              250, 500, "Pacas"
            ),

            // Item 3: Nivel Crítico (Rojo)
            _itemStock(
              "Melaza Líquida", 
              Icons.water_drop, 
              150, 2000, "Litros"
            ),

            // Item 4: Otro ejemplo
            _itemStock(
              "Sal Mineral", 
              Icons.eco, 
              850, 1000, "Kg"
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET PERSONALIZADO PARA CADA ITEM ---
  Widget _itemStock(String nombre, IconData icono, double actual, double maximo, String unidad) {
    // Cálculo del porcentaje (0.0 a 1.0)
    double porcentaje = actual / maximo;
    
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