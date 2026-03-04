import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  @override
  void initState() {
    super.initState();
    _cargarDatosDeLaNube(); // Ejecuta la lectura de Firebase al abrir
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
      // 1. EXTRAER TOTAL DE GANADO
      var ganadoObtenido = await FirebaseFirestore.instance.collection('ganado').get();
      contadorCabezas = ganadoObtenido.docs.length;

      // 2. EXTRAER TOTAL DE DINERO EN VENTAS
      var ventasObtenidas = await FirebaseFirestore.instance.collection('ventas_salidas').get();
      for (var doc in ventasObtenidas.docs) {
        sumaVentas += (doc.data()['monto_total'] ?? 0.0);
      }

      // 3. REVISAR INVENTARIO (Buscando lo que se terminó o está por terminarse)
      var inventarioObtenido = await FirebaseFirestore.instance.collection('inventario').get();
      for (var doc in inventarioObtenido.docs) {
        var datos = doc.data();
        String nombreInsumo = datos['nombre'] ?? 'Producto Desconocido';
        double actual = (datos['cantidad_actual'] ?? 0).toDouble();
        double maxima = (datos['capacidad_maxima'] ?? 100).toDouble();
        String unidad = datos['unidad'] ?? 'Und';
        
        if (maxima <= 0) maxima = 1; // Protección matemática
        double porcentaje = actual / maxima;

        // Lógica de Alertas Inteligentes
        if (actual <= 0) {
          // CASO 1: SE TERMINÓ EL ALIMENTO COMPLETAMENTE
          contadorAlertasCriticas++;
          alertasReales.add({
            "titulo": nombreInsumo,
            "mensaje": "¡TOTALMENTE AGOTADO! (0 $unidad)",
            "tipo": "critico"
          });
        } else if (porcentaje <= 0.20) {
          // CASO 2: ESTÁ A PUNTO DE TERMINARSE (Menos del 20%)
          contadorAlertasCriticas++;
          alertasReales.add({
            "titulo": nombreInsumo,
            "mensaje": "Nivel muy bajo, quedan solo ${actual.toInt()} $unidad",
            "tipo": "critico"
          });
        } else if (porcentaje <= 0.50) {
          // CASO 3: A LA MITAD (Se muestra la alerta pero no se cuenta como crítica)
          alertasReales.add({
            "titulo": nombreInsumo,
            "mensaje": "Nivel medio al ${(porcentaje * 100).toInt()}%",
            "tipo": "advertencia"
          });
        }
      }

      // Si todo está lleno, agregamos un mensaje positivo
      if (alertasReales.isEmpty) {
        alertasReales.add({
          "titulo": "Inventario Sano",
          "mensaje": "Tienes suficiente alimento y medicinas.",
          "tipo": "info"
        });
      }

      // 4. ACTUALIZAR LA PANTALLA
      if (mounted) {
        setState(() {
          _totalCabezas = contadorCabezas.toString();
          // Formateamos el dinero para que se vea bonito (ej. $15,000.00)
          _ventasMes = "\$${sumaVentas.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}";
          _alertasStock = contadorAlertasCriticas.toString();
          
          // Mostramos las primeras 5 alertas
          _listaAlertas = alertasReales.take(5).toList(); 
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

  @override
  Widget build(BuildContext context) {
    final Color azulAgro = const Color(0xFF01579B);
    final Color verdeVenta = const Color(0xFF2E7D32);

    return LayoutBuilder(
      builder: (context, constraints) {
        bool esMovil = constraints.maxWidth < 850;

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
            onRefresh: _cargarDatosDeLaNube, // Permite recargar al deslizar hacia abajo
            color: azulAgro,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- HEADER ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("Resumen General", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF263238))),
                          Text("Rancho en Guadalupe Victoria", style: TextStyle(color: Colors.grey, fontSize: 16)),
                        ],
                      ),
                      if (!esMovil) _widgetClima(),
                    ],
                  ),
                  
                  const SizedBox(height: 30),

                  // --- TARJETAS KPI (CON DATOS REALES) ---
                  if (esMovil)
                    Column(
                      children: [
                        _widgetClima(),
                        const SizedBox(height: 20),
                        _kpiCard("Total Cabezas", _totalCabezas, Icons.grass, azulAgro),
                        const SizedBox(height: 15),
                        // Si hay alertas críticas, la tarjeta se pinta roja, si no, naranja
                        _kpiCard("Alertas de Stock", _alertasStock, Icons.warning_amber_rounded, int.parse(_alertasStock) > 0 ? Colors.red : Colors.orange),
                        const SizedBox(height: 15),
                        _kpiCard("Ventas Acumuladas", _ventasMes, Icons.attach_money, verdeVenta),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(child: _kpiCard("Total Cabezas", _totalCabezas, Icons.grass, azulAgro)),
                        const SizedBox(width: 20),
                        Expanded(child: _kpiCard("Alertas de Stock", _alertasStock, Icons.warning_amber_rounded, int.parse(_alertasStock) > 0 ? Colors.red : Colors.orange)),
                        const SizedBox(width: 20),
                        Expanded(child: _kpiCard("Ventas Acumuladas", _ventasMes, Icons.attach_money, verdeVenta)),
                      ],
                    ),

                  const SizedBox(height: 30),

                  // --- ACCESOS RÁPIDOS ---
                  const Text("Accesos Rápidos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 15),
                  _seccionAccesosRapidos(azulAgro),

                  const SizedBox(height: 30),

                  // --- ALERTAS REALES Y GRÁFICA ---
                  if (esMovil)
                    Column(
                      children: [
                        _seccionAlertas(azulAgro),
                        const SizedBox(height: 20),
                        _seccionGraficaSimulada(),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 1, child: _seccionAlertas(azulAgro)),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: _seccionGraficaSimulada()),
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
          const Text("Producción (Tendencia Semanal)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Text("Gráfica proyectada", style: TextStyle(color: Colors.grey, fontSize: 12)),
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
              Text("⚠️ Avisos de Inventario", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                Text(mensaje, style: TextStyle(fontSize: 12, color: color == Colors.red ? Colors.red[700] : Colors.grey[600], fontWeight: color == Colors.red ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          )
        ],
      ),
    );
  }
}