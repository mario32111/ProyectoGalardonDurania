import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VistaLogin extends StatefulWidget {
  const VistaLogin({super.key});

  @override
  State<VistaLogin> createState() => _VistaLoginState();
}

class _VistaLoginState extends State<VistaLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;

  final Color azulPrincipal = const Color(0xFF01579B);
  final Color azulClaro = const Color(0xFF29B6F6);

  Future<void> _autenticar() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _mostrarError("Por favor completa todos los campos.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      _mostrarError(e.message ?? "Ocurrió un error de autenticación.");
    } catch (e) {
      _mostrarError("Error inesperado: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [azulPrincipal, azulClaro],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Card(
              elevation: 15,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // LOGO / ICONO
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: azulPrincipal.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.grass_rounded, size: 60, color: azulPrincipal),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _isLogin ? "Bienvenido de Nuevo" : "Crea tu Cuenta",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: azulPrincipal,
                      ),
                    ),
                    Text(
                      _isLogin 
                        ? "Ingresa tus datos para continuar" 
                        : "Regístrate para empezar a gestionar",
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 35),
                    
                    // INPUT EMAIL
                    _buildTextField(
                      controller: _emailController,
                      label: "Correo Electrónico",
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    
                    // INPUT PASSWORD
                    _buildTextField(
                      controller: _passwordController,
                      label: "Contraseña",
                      icon: Icons.lock_outline,
                      isPassword: true,
                    ),
                    const SizedBox(height: 35),
                    
                    // BOTÓN PRINCIPAL
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _autenticar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: azulPrincipal,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 5,
                        ),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              _isLogin ? "INICIAR SESIÓN" : "REGISTRARSE",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // BOTÓN CAMBIO MODO
                    TextButton(
                      onPressed: () => setState(() => _isLogin = !_isLogin),
                      child: Text(
                        _isLogin 
                          ? "¿No tienes cuenta? Regístrate aquí" 
                          : "¿Ya tienes cuenta? Inicia sesión",
                        style: TextStyle(color: azulPrincipal, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: azulPrincipal),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: azulClaro, width: 2),
        ),
      ),
    );
  }
}
