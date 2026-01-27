import 'package:flutter/material.dart';

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

  // ==============================================================================
  //  SIMULACIÓN DE CONEXIÓN
  // ==============================================================================
  @override
  void initState() {
    super.initState();
    _cargarDatosBackend();
  }

  Future<void> _cargarDatosBackend() async {
    // Simulación de carga
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _totalCabezas = "1,240";
        _alertasStock = "3";
        _ventasMes = "\$450k";

        _listaAlertas = [
          {"titulo": "Melaza Líquida", "mensaje": "Stock Crítico (5%)", "tipo": "critico"},
          {"titulo": "Corral 4", "mensaje": "Revisión Veterinaria pendiente", "tipo": "advertencia"},
          {"titulo": "Vacunación", "mensaje": "Próxima campaña en 3 días", "tipo": "info"},
        ];

        _estaCargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // REGRESAMOS AL AZUL
    final Color azulAgro = const Color(0xFF01579B);
    final Color verdeVenta = const Color(0xFF2E7D32); // El dinero se queda verde

    return LayoutBuilder(
      builder: (context, constraints) {
        bool esMovil = constraints.maxWidth < 850;

        if (_estaCargando) {
          // Spinner Azul
          return Center(child: CircularProgressIndicator(color: azulAgro));
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Resumen General", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF263238))),
                const Text("Bienvenido al Panel de Control", style: TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 30),

                if (esMovil)
                  Column(
                    children: [
                      _kpiCard("Total Cabezas", _totalCabezas, Icons.grass, azulAgro), // Azul
                      const SizedBox(height: 15),
                      _kpiCard("Alertas Stock", _alertasStock, Icons.warning_amber_rounded, Colors.orange),
                      const SizedBox(height: 15),
                      _kpiCard("Ventas Mes", _ventasMes, Icons.attach_money, verdeVenta),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(child: _kpiCard("Total Cabezas", _totalCabezas, Icons.grass, azulAgro)), // Azul
                      const SizedBox(width: 20),
                      Expanded(child: _kpiCard("Alertas Stock", _alertasStock, Icons.warning_amber_rounded, Colors.orange)),
                      const SizedBox(width: 20),
                      Expanded(child: _kpiCard("Ventas Mes", _ventasMes, Icons.attach_money, verdeVenta)),
                    ],
                  ),
                
                const SizedBox(height: 30),

                // ALERTAS
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

                      if (_listaAlertas.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text("¡Todo en orden!", style: TextStyle(color: Colors.grey)),
                        )
                      else
                        ..._listaAlertas.map((alerta) {
                          Color colorAlerta;
                          switch (alerta['tipo']) {
                            case 'critico': colorAlerta = Colors.red; break;
                            case 'advertencia': colorAlerta = Colors.orange; break;
                            default: colorAlerta = azulAgro; // Azul
                          }
                          return _alertaItem(alerta['titulo'], alerta['mensaje'], colorAlerta);
                        }).toList(),
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

  Widget _kpiCard(String titulo, String valor, IconData icono, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: color, width: 5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icono, color: color, size: 30),
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
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(mensaje, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          )
        ],
      ),
    );
  }
}