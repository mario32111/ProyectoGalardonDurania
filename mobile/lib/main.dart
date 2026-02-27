import 'package:flutter/material.dart';
// --- LIBRERÍAS DE FIREBASE AGREGADAS ---
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// --- TUS IMPORTACIONES DE VISTAS ---
// Asegúrate de que estas rutas sean correctas en tu proyecto
import 'ui/vistas/dashboard/dashboard_inicio.dart';
import 'ui/vistas/ganado/manejo_ganado.dart';
import 'ui/vistas/ganado/compra_grupal.dart';
import 'ui/vistas/ganado/salida_venta.dart';
import 'ui/vistas/inventario/stock_alimentos.dart';
import 'ui/vistas/inventario/comprar_producto.dart';
import 'ui/widgets/agrobot_chat.dart';

// --- IMPORTACIÓN DEL MAPA (CORREGIDA) ---
// Esta ruta asume que guardaste el archivo del mapa en: lib/ui/vistas/mapa/mapa_ganado.dart
import 'ui/vistas/mapa/mapa_ganado.dart'; 

// --- MOTOR DE ARRANQUE CON FIREBASE ---
void main() async {
  // 1. Asegura que Flutter esté listo
  WidgetsFlutterBinding.ensureInitialized(); 
  
  // 2. Enciende Firebase con tus credenciales
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 3. Arranca tu aplicación
  runApp(const AgroControlApp());
}

class AgroControlApp extends StatelessWidget {
  const AgroControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Color principal de la marca
    final Color azulAgro = const Color(0xFF01579B);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AgroControl Pro',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: azulAgro),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        // Tema global para la AppBar
        appBarTheme: AppBarTheme(
          backgroundColor: azulAgro,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
        ),
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Estado que controla qué vista se muestra
  String _vistaActual = "INICIO";
  
  final Color azulAgro = const Color(0xFF01579B);

  // Función para cambiar la vista desde el menú
  void _cambiarVista(String vista) {
    setState(() {
      _vistaActual = vista;
    });
    // Cierra el drawer si estamos en móvil
    if (_scaffoldKey.currentState != null && _scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.closeDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Detectamos si es pantalla móvil (menos de 850px)
        bool esMovil = constraints.maxWidth < 850;

        return Scaffold(
          key: _scaffoldKey,
          
          // AppBar solo visible en móvil
          appBar: esMovil 
              ? AppBar(
                  title: const Text("AGROCONTROL", style: TextStyle(fontWeight: FontWeight.bold)),
                  leading: IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                )
              : null,

          // Menú lateral desplegable (solo móvil)
          drawer: esMovil 
              ? Drawer(
                  child: MenuLateralInterno(
                    vistaActual: _vistaActual,
                    onOpcionSeleccionada: _cambiarVista,
                  ),
                )
              : null,

          // Botón flotante del Chatbot (Agrobot)
          floatingActionButton: FloatingActionButton(
            backgroundColor: azulAgro,
            child: const Icon(Icons.smart_toy, color: Colors.white, size: 30),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const AgrobotChatWidget(),
              );
            },
          ),

          // Cuerpo principal de la aplicación
          body: Row(
            children: [
              // Si es escritorio/tablet, mostramos el menú fijo a la izquierda
              if (!esMovil)
                MenuLateralInterno(
                  vistaActual: _vistaActual,
                  onOpcionSeleccionada: _cambiarVista,
                ),
              
              // Área de contenido dinámico
              Expanded(
                child: Container(
                  padding: EdgeInsets.zero,
                  child: _seleccionarVista(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Selector de Vistas (Aquí estaba el error anterior)
  Widget _seleccionarVista() {
    switch (_vistaActual) {
      case "INICIO":           return const VistaDashboardInicio();
      case "Manejo De Ganado": return const VistaManejoGanado();
      case "Compra Grupal":    return const VistaCompraGrupal();
      case "Salida Por Venta": return const VistaSalidaVenta();
      
      // --- CORRECCIÓN: Usamos la clase MapaGanado ---
      case "Mapa General":     return const MapaGanado(); 
      
      case "Stock Alimentos":  return const VistaStockAlimentos();
      case "Comprar Producto": return const VistaComprarProducto();
      
      default: return const VistaDashboardInicio();
    }
  }
}

// Widget del Menú Lateral (Reutilizable)
class MenuLateralInterno extends StatefulWidget {
  final Function(String) onOpcionSeleccionada;
  final String vistaActual;

  const MenuLateralInterno({
    super.key, 
    required this.onOpcionSeleccionada, 
    required this.vistaActual
  });

  @override
  State<MenuLateralInterno> createState() => _MenuLateralInternoState();
}

class _MenuLateralInternoState extends State<MenuLateralInterno> {
  // Controla qué grupo del menú está desplegado
  String _menuDesplegado = "Ganado";
  
  final Color azulAgro = const Color(0xFF01579B);
  final Color naranjaInventario = const Color(0xFFEF6C00);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Logo / Título del Menú
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "AGROCONTROL", 
                style: TextStyle(
                  fontSize: 26, 
                  fontWeight: FontWeight.w900, 
                  color: azulAgro
                )
              ),
              const Text(
                "GESTIÓN INTELIGENTE", 
                style: TextStyle(
                  color: Colors.grey, 
                  fontSize: 10, 
                  letterSpacing: 3.0, 
                  fontWeight: FontWeight.bold
                )
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),

          // Lista de opciones del menú
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // --- GRUPO GANADO ---
                _buildTituloMenu("Ganado", Icons.grass, azulAgro),
                if (_menuDesplegado == "Ganado") ...[
                  // Opción para abrir el Mapa
                  _btnSubMenu("Mapa General", icon: Icons.map_outlined),
                  _btnSubMenu("Manejo De Ganado"),
                  _btnSubMenu("Compra Grupal"),
                  _btnSubMenu("Salida Por Venta"),
                ],

                // --- GRUPO INVENTARIO ---
                _buildTituloMenu("Inventario", Icons.inventory_2, naranjaInventario),
                if (_menuDesplegado == "Inventario") ...[
                  _btnSubMenu("Stock Alimentos"),
                  _btnSubMenu("Comprar Producto"),
                ],
                
                // --- OPCIÓN INICIO ---
                ListTile(
                  leading: const Icon(Icons.dashboard, color: Colors.grey),
                  title: const Text("Tablero Inicio", style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => widget.onOpcionSeleccionada("INICIO"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget auxiliar para títulos de sección (con flechita)
  Widget _buildTituloMenu(String titulo, IconData icono, Color color) {
    bool desplegado = _menuDesplegado == titulo;
    return ListTile(
      onTap: () => setState(() => _menuDesplegado = desplegado ? "" : titulo),
      leading: Icon(icono, color: desplegado ? color : Colors.grey),
      title: Text(
        titulo, 
        style: TextStyle(
          fontWeight: FontWeight.bold, 
          color: desplegado ? color : Colors.black87
        )
      ),
      trailing: Icon(desplegado ? Icons.keyboard_arrow_down : Icons.chevron_right),
    );
  }

  // Widget auxiliar para los botones de submenú
  Widget _btnSubMenu(String titulo, {IconData? icon}) {
    bool activo = widget.vistaActual == titulo;
    Color colorActivo = _menuDesplegado == "Inventario" ? naranjaInventario : azulAgro;
    
    return Container(
      color: activo ? colorActivo.withOpacity(0.1) : Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 50),
        leading: icon != null 
            ? Icon(icon, size: 20, color: activo ? colorActivo : Colors.grey) 
            : null,
        title: Text(
          titulo, 
          style: TextStyle(
            fontWeight: activo ? FontWeight.bold : FontWeight.normal, 
            color: activo ? colorActivo : Colors.black54
          )
        ),
        onTap: () => widget.onOpcionSeleccionada(titulo),
      ),
    );
  }
}