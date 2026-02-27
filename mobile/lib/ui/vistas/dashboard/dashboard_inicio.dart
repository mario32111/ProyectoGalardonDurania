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
    final Color azulAgro = const Color(0xFF01579B);
    final Color verdeVenta = const Color(0xFF2E7D32);

    return LayoutBuilder(
      builder: (context, constraints) {
        bool esMovil = constraints.maxWidth < 850;

        if (_estaCargando) {
          return Center(child: CircularProgressIndicator(color: azulAgro));
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FA),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER CON SALUDO Y CLIMA
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text("Resumen General", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF263238))),
                        Text("Rancho Santa Fe", style: TextStyle(color: Colors.grey, fontSize: 16)),
                      ],
                    ),
                    if (!esMovil) _widgetClima(), // En escritorio lo mostramos arriba
                  ],
                ),
                
                const SizedBox(height: 30),

                // 1. TARJETAS KPI (YA LAS TENÍAS, MUY BIEN)
                if (esMovil)
                  Column(
                    children: [
                      _widgetClima(), // En móvil lo ponemos aquí
                      const SizedBox(height: 20),
                      _kpiCard("Total Cabezas", _totalCabezas, Icons.grass, azulAgro),
                      const SizedBox(height: 15),
                      _kpiCard("Alertas Stock", _alertasStock, Icons.warning_amber_rounded, Colors.orange),
                      const SizedBox(height: 15),
                      _kpiCard("Ventas Mes", _ventasMes, Icons.attach_money, verdeVenta),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(child: _kpiCard("Total Cabezas", _totalCabezas, Icons.grass, azulAgro)),
                      const SizedBox(width: 20),
                      Expanded(child: _kpiCard("Alertas Stock", _alertasStock, Icons.warning_amber_rounded, Colors.orange)),
                      const SizedBox(width: 20),
                      Expanded(child: _kpiCard("Ventas Mes", _ventasMes, Icons.attach_money, verdeVenta)),
                    ],
                  ),

                const SizedBox(height: 30),

                // 2. NUEVO: ACCESOS RÁPIDOS (BOTONERA)
                const Text("Accesos Rápidos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 15),
                _seccionAccesosRapidos(azulAgro),

                const SizedBox(height: 30),

                // 3. LAYOUT MIXTO: GRÁFICA + ALERTAS
                if (esMovil)
                  Column(
                    children: [
                      _seccionGraficaSimulada(),
                      const SizedBox(height: 20),
                      _seccionAlertas(azulAgro),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _seccionGraficaSimulada()),
                      const SizedBox(width: 20),
                      Expanded(flex: 1, child: _seccionAlertas(azulAgro)),
                    ],
                  ),
                  
                const SizedBox(height: 50), // Espacio final
              ],
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
    return Container(
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

  // --- NUEVO: WIDGET DE CLIMA ---
  Widget _widgetClima() {
    return Container(
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
    );
  }

  // --- NUEVO: ACCESOS RÁPIDOS ---
  Widget _seccionAccesosRapidos(Color colorTema) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _botonRapido(Icons.add_circle_outline, "Nuevo\nAnimal", colorTema),
        _botonRapido(Icons.local_hospital_outlined, "Reportar\nEnfermedad", Colors.redAccent),
        _botonRapido(Icons.attach_money, "Registrar\nVenta", Colors.green),
        _botonRapido(Icons.inventory_2_outlined, "Pedir\nInsumos", Colors.orange),
      ],
    );
  }

  Widget _botonRapido(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
      ],
    );
  }

  // --- NUEVO: GRÁFICA SIMULADA (BARRAS) ---
  Widget _seccionGraficaSimulada() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Producción de Leche (Semanal)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Text("Litros diarios", style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _barraGrafica("Lun", 0.6),
                _barraGrafica("Mar", 0.8),
                _barraGrafica("Mie", 0.7),
                _barraGrafica("Jue", 0.9, activo: true),
                _barraGrafica("Vie", 0.5),
                _barraGrafica("Sab", 0.6),
                _barraGrafica("Dom", 0.4),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _barraGrafica(String dia, double porcentaje, {bool activo = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 20,
          height: 100 * porcentaje,
          decoration: BoxDecoration(
            color: activo ? const Color(0xFF01579B) : Colors.grey[200],
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: 8),
        Text(dia, style: TextStyle(fontSize: 12, color: activo ? Colors.black : Colors.grey)),
      ],
    );
  }

  // --- SECCIÓN DE ALERTAS (YA LA TENÍAS, LA EMPAQUETÉ) ---
  Widget _seccionAlertas(Color colorTema) {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("⚠️ Alertas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text("Ver todo", style: TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 30),
          if (_listaAlertas.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Text("¡Todo en orden!", style: TextStyle(color: Colors.grey)))
          else
            ..._listaAlertas.map((alerta) {
              Color colorAlerta;
              switch (alerta['tipo']) {
                case 'critico': colorAlerta = Colors.red; break;
                case 'advertencia': colorAlerta = Colors.orange; break;
                default: colorAlerta = colorTema;
              }
              return _alertaItem(alerta['titulo'], alerta['mensaje'], colorAlerta);
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
                Text(mensaje, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          )
        ],
      ),
    );
  }
}