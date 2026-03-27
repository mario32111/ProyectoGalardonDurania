import 'package:flutter/material.dart';
// --- LIBRERÍAS DE FIREBASE AGREGADAS ---
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- AUTH AGREGADO
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'ui/vistas/auth/login_vista.dart';

// --- TUS IMPORTACIONES DE VISTAS ---
import 'ui/vistas/dashboard/dashboard_inicio.dart';
import 'ui/vistas/ganado/manejo_ganado.dart';
import 'ui/vistas/ganado/compra_grupal.dart';
import 'ui/vistas/ganado/salida_venta.dart';
import 'ui/vistas/inventario/stock_alimentos.dart';
import 'ui/vistas/inventario/comprar_producto.dart';
import 'ui/widgets/agrobot_chat.dart';
import 'ui/vistas/mapa/mapa_ganado.dart'; 

// --- IMPORTACIÓN DE DOCS ---
import 'ui/vistas/Docs/Docs.dart';

// --- MOTOR DE ARRANQUE CON FIREBASE ---
void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await NotificationService().initialize();

  runApp(const AgroControlApp());
}

class AgroControlApp extends StatelessWidget {
  const AgroControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Color azulAgro = const Color(0xFF01579B);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AgroControl Pro',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: azulAgro),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: AppBarTheme(
          backgroundColor: azulAgro,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 2,
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const PantallaPrincipal(); // Si hay usuario logueado
          }
          return const VistaLogin(); // Si no hay usuario
        },
      ),
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
  
  String _vistaActual = "INICIO";
  
  final Color azulAgro = const Color(0xFF01579B);

  void _cambiarVista(String vista) {
    setState(() {
      _vistaActual = vista;
    });
    if (_scaffoldKey.currentState != null && _scaffoldKey.currentState!.isDrawerOpen) {
      _scaffoldKey.currentState!.closeDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool esMovil = constraints.maxWidth < 850;

        return Scaffold(
          key: _scaffoldKey,
          
          appBar: esMovil 
              ? AppBar(
                  title: const Text("AGROCONTROL", style: TextStyle(fontWeight: FontWeight.bold)),
                  leading: IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                )
              : null,

          drawer: esMovil 
              ? Drawer(
                  child: MenuLateralInterno(
                    vistaActual: _vistaActual,
                    onOpcionSeleccionada: _cambiarVista,
                  ),
                )
              : null,

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

          body: Row(
            children: [
              if (!esMovil)
                MenuLateralInterno(
                  vistaActual: _vistaActual,
                  onOpcionSeleccionada: _cambiarVista,
                ),
              
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

  // --- RUTEADOR DE VISTAS ---
  Widget _seleccionarVista() {
    switch (_vistaActual) {
      case "INICIO":           return const VistaDashboardInicio();
      case "Manejo De Ganado": return const VistaManejoGanado();
      case "Compra Grupal":    return const VistaCompraGrupal();
      case "Salida Por Venta": return const VistaSalidaVenta();
      case "Mapa General":     return const MapaGanado(); 
      case "Stock Alimentos":  return const VistaStockAlimentos();
      case "Comprar Producto": return const VistaComprarProducto();
      case "Docs":             return const VistaTramitesVentanilla(); 
      
      default: return const VistaDashboardInicio();
    }
  }
}

// ====================================================
// WIDGET DEL MENÚ LATERAL
// ====================================================
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
  String _menuDesplegado = "Ganado";
  
  final Color azulAgro = const Color(0xFF01579B);
  final Color naranjaInventario = const Color(0xFFEF6C00);
  final Color rojoAdministracion = const Color(0xFFD32F2F); 

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 40),
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

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // --- 0. OPCIÓN INICIO (AHORA AL PRINCIPIO) ---
                ListTile(
                  leading: Icon(Icons.dashboard, color: widget.vistaActual == "INICIO" ? azulAgro : Colors.grey),
                  title: Text(
                    "Tablero Inicio", 
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: widget.vistaActual == "INICIO" ? azulAgro : Colors.black87
                    )
                  ),
                  onTap: () => widget.onOpcionSeleccionada("INICIO"),
                ),

                const Divider(),

                // --- 1. GRUPO GANADO ---
                _buildTituloMenu("Ganado", Icons.grass, azulAgro),
                if (_menuDesplegado == "Ganado") ...[
                  _btnSubMenu("Mapa General", icon: Icons.map_outlined),
                  _btnSubMenu("Manejo De Ganado"),
                  _btnSubMenu("Compra Grupal"),
                  _btnSubMenu("Salida Por Venta"),
                ],

                // --- 2. GRUPO INVENTARIO ---
                _buildTituloMenu("Inventario", Icons.inventory_2, naranjaInventario),
                if (_menuDesplegado == "Inventario") ...[
                  _btnSubMenu("Stock Alimentos"),
                  _btnSubMenu("Comprar Producto"),
                ],

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(height: 30),
                ),

                // --- 3. BOTÓN SUELTO DE DOCS ---
                ListTile(
                  leading: Icon(
                    Icons.folder_shared, 
                    color: widget.vistaActual == "Docs" ? rojoAdministracion : Colors.grey
                  ),
                  title: Text(
                    "Trámites (Docs)", 
                    style: TextStyle(
                      fontWeight: widget.vistaActual == "Docs" ? FontWeight.bold : FontWeight.normal,
                      color: widget.vistaActual == "Docs" ? rojoAdministracion : Colors.black87
                    )
                  ),
                  onTap: () => widget.onOpcionSeleccionada("Docs"), 
                ),

                const SizedBox(height: 20),
                const Divider(),
                
                // --- BOTÓN CERRAR SESIÓN ---
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.grey),
                  title: const Text("Cerrar Sesión", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _btnSubMenu(String titulo, {IconData? icon}) {
    bool activo = widget.vistaActual == titulo;
    
    Color colorActivo = azulAgro; 
    if (_menuDesplegado == "Inventario") colorActivo = naranjaInventario;
    
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