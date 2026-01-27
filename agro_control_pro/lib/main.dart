import 'package:flutter/material.dart';

// --- TUS VISTAS ORIGINALES (NO SE TOCAN) ---
import 'ui/vistas/dashboard/dashboard_inicio.dart';
import 'ui/vistas/ganado/manejo_ganado.dart';
import 'ui/vistas/ganado/compra_grupal.dart';
import 'ui/vistas/ganado/salida_venta.dart';
import 'ui/vistas/inventario/stock_alimentos.dart';
import 'ui/vistas/inventario/comprar_producto.dart';

void main() {
  runApp(const AgroControlApp());
}

class AgroControlApp extends StatelessWidget {
  const AgroControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AgroControl Pro',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF01579B)),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      home: const PantallaPrincipal(),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  String _vistaActual = "INICIO";
  String _menuDesplegado = "Ganado";

  final Color azulAgro = const Color(0xFF01579B);
  final Color naranjaInventario = const Color(0xFFEF6C00);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ---------------------------------------------------------
      // AQUÍ ESTÁ EL CAMBIO DE TAMAÑO (0.85)
      // ---------------------------------------------------------
      floatingActionButton: FloatingActionButton(
        backgroundColor: azulAgro,
        child: const Icon(Icons.smart_toy, color: Colors.white, size: 30),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true, // Permite altura personalizada
            backgroundColor: Colors.transparent,
            builder: (context) => Container(
              // --- TAMAÑO AJUSTADO: 85% DE LA PANTALLA ---
              height: MediaQuery.of(context).size.height * 0.85, 
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 15),
                  // Barrita gris superior
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                  
                  // CONTENIDO TEMPORAL (Se reemplazará cuando crees el archivo del chat)
                  const Spacer(),
                  const Icon(Icons.smart_toy, size: 80, color: Colors.blueGrey),
                  const SizedBox(height: 20),
                  const Text(
                    "AgroBot Grande", 
                    style: TextStyle(fontSize: 22, color: Colors.black87, fontWeight: FontWeight.bold)
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Este panel ahora ocupa el 85% de la pantalla para mayor comodidad.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          );
        },
      ),

      // --- ESTRUCTURA ORIGINAL (MENU Y CUERPO) ---
      body: Row(
        children: [
          // MENÚ LATERAL
          Container(
            width: 280,
            color: Colors.white,
            child: Column(
              children: [
                const SizedBox(height: 40),
                Text("AGROCONTROL", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: azulAgro)),
                Text("Sistema Modular v2.0", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 40),

                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // GANADO
                      _buildTituloMenu("Ganado", Icons.pets, azulAgro),
                      if (_menuDesplegado == "Ganado") ...[
                        _buildBotonSubMenu("Manejo De Ganado"),
                        _buildBotonSubMenu("Compra Grupal"),
                        _buildBotonSubMenu("Salida Por Venta"),
                      ],

                      // INVENTARIO
                      _buildTituloMenu("Inventario", Icons.inventory_2, naranjaInventario),
                      if (_menuDesplegado == "Inventario") ...[
                        _buildBotonSubMenu("Stock Alimentos"),
                        _buildBotonSubMenu("Comprar Producto"),
                      ],
                      
                      // INICIO
                      ListTile(
                        leading: const Icon(Icons.dashboard, color: Colors.grey),
                        title: const Text("Tablero Inicio", style: TextStyle(fontWeight: FontWeight.bold)),
                        onTap: () => setState(() => _vistaActual = "INICIO"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ÁREA DE CONTENIDO (ROUTER ORIGINAL)
          Expanded(
            child: Container(
              child: _seleccionarVista(),
            ),
          ),
        ],
      ),
    );
  }

  // --- ROUTER ORIGINAL ---
  Widget _seleccionarVista() {
    switch (_vistaActual) {
      case "INICIO":           return const VistaDashboardInicio();
      case "Manejo De Ganado": return const VistaManejoGanado();
      case "Compra Grupal":    return const VistaCompraGrupal();
      case "Salida Por Venta": return const VistaSalidaVenta();
      case "Stock Alimentos":  return const VistaStockAlimentos();
      case "Comprar Producto": return const VistaComprarProducto();
      default: return const VistaDashboardInicio();
    }
  }

  // --- WIDGETS DEL MENÚ ORIGINALES ---
  Widget _buildTituloMenu(String titulo, IconData icono, Color color) {
    bool desplegado = _menuDesplegado == titulo;
    return ListTile(
      onTap: () => setState(() => _menuDesplegado = desplegado ? "" : titulo),
      leading: Icon(icono, color: desplegado ? color : Colors.grey),
      title: Text(titulo, style: TextStyle(fontWeight: FontWeight.bold, color: desplegado ? color : Colors.black87)),
      trailing: Icon(desplegado ? Icons.keyboard_arrow_down : Icons.chevron_right),
    );
  }

  Widget _buildBotonSubMenu(String titulo) {
    bool activo = _vistaActual == titulo;
    Color colorActivo = _menuDesplegado == "Inventario" ? naranjaInventario : azulAgro;
    return Container(
      color: activo ? colorActivo.withOpacity(0.1) : Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 50),
        title: Text(titulo, style: TextStyle(fontWeight: activo ? FontWeight.bold : FontWeight.normal, color: activo ? colorActivo : Colors.black54)),
        onTap: () => setState(() => _vistaActual = titulo),
      ),
    );
  }
}