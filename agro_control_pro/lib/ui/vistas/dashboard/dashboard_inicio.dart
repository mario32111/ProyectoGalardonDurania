import 'package:flutter/material.dart';

class VistaDashboardInicio extends StatelessWidget {
  const VistaDashboardInicio({super.key});

  @override
  Widget build(BuildContext context) {
    final Color azulAgro = const Color(0xFF01579B);
    final Color verdeVenta = const Color(0xFF2E7D32);

    // USAMOS LAYOUTBUILDER PARA HACERLO RESPONSIVO
    return LayoutBuilder(
      builder: (context, constraints) {
        // Si el ancho es menor a 800px, es móvil/tablet vertical
        bool esMovil = constraints.maxWidth < 800;

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER
                const Text("Resumen General", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF263238))),
                const Text("Bienvenido al Panel de Control", style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 30),

                // KPI CARDS (RESPONSIVE)
                if (esMovil)
                  // MODO MÓVIL: Columna (Uno abajo del otro)
                  Column(
                    children: [
                      _kpiCard("Total Cabezas", "1,240", Icons.pets, azulAgro),
                      const SizedBox(height: 15),
                      _kpiCard("Alertas Stock", "3", Icons.warning_amber_rounded, Colors.orange),
                      const SizedBox(height: 15),
                      _kpiCard("Ventas Mes", "\$450k", Icons.attach_money, verdeVenta),
                    ],
                  )
                else
                  // MODO PC: Fila (Uno al lado del otro)
                  Row(
                    children: [
                      Expanded(child: _kpiCard("Total Cabezas", "1,240", Icons.pets, azulAgro)),
                      const SizedBox(width: 20),
                      Expanded(child: _kpiCard("Alertas Stock", "3", Icons.warning_amber_rounded, Colors.orange)),
                      const SizedBox(width: 20),
                      Expanded(child: _kpiCard("Ventas Mes", "\$450k", Icons.attach_money, verdeVenta)),
                    ],
                  ),
                
                const SizedBox(height: 30),

                // SECCIÓN DE ALERTAS
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("⚠️ Atención Requerida", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const Divider(height: 30),
                      _alertaItem("Melaza Líquida", "Stock Crítico (5%)", Colors.red),
                      _alertaItem("Corral 4", "Revisión Veterinaria pendiente", Colors.orange),
                      _alertaItem("Vacunación", "Próxima campaña en 3 días", azulAgro),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _kpiCard(String titulo, String valor, IconData icono, Color color) {
    return Container(
      width: double.infinity, // Asegura que ocupe todo el ancho disponible en móvil
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icono, color: color, size: 30),
              // Indicador visual opcional
              Icon(Icons.more_horiz, color: Colors.grey[300]),
            ],
          ),
          const SizedBox(height: 15),
          Text(valor, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
          Text(titulo, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _alertaItem(String titulo, String mensaje, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 15),
          Expanded( // Expanded evita que textos largos rompan el diseño en celulares pequeños
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 15)),
                Text(mensaje, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
            ),
          )
        ],
      ),
    );
  }
}