import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VistaIdDigital extends StatefulWidget {
  const VistaIdDigital({super.key});

  @override
  State<VistaIdDigital> createState() => _VistaIdDigitalState();
}

class _VistaIdDigitalState extends State<VistaIdDigital> {
  static const String _serverUrl = 'http://192.168.1.72:3000';
  
  bool _isLoading = true;
  List<dynamic> _credentials = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCredentials();
  }

  Future<void> _fetchCredentials() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Usuario no autenticado");
      
      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$_serverUrl/wallet/api/list'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _credentials = data['data'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addToGoogleWallet(String credentialId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final token = await user.getIdToken();
      final response = await http.get(
        Uri.parse('$_serverUrl/wallet/api/save-link/$credentialId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String url = data['url'];
        
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
          throw Exception("No se pudo abrir el enlace de Google Wallet");
        }
      } else {
        throw Exception("Error al generar el link: ${response.statusCode}");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color azulAgro = const Color(0xFF01579B);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("ID Digital Ganadera", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: azulAgro,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: Colors.red),
                    const SizedBox(height: 10),
                    Text("Error al cargar IDs: $_error", textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(onPressed: _fetchCredentials, child: const Text("Reintentar")),
                  ],
                ),
              ),
            )
          : _credentials.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.badge_outlined, size: 80, color: Colors.grey[300]),
                    const SizedBox(height: 20),
                    const Text("No tienes IDs digitales aún", style: TextStyle(fontSize: 18, color: Colors.grey)),
                    const SizedBox(height: 10),
                    const Text("Crea uno desde el panel administrativo", style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _credentials.length,
                itemBuilder: (context, index) {
                  final cred = _credentials[index];
                  return _buildCredentialCard(cred);
                },
              ),
    );
  }

  Widget _buildCredentialCard(dynamic cred) {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      child: Column(
        children: [
          // PREVIEW DE LA TARJETA (Estilo Google Wallet)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F4A3E), Color(0xFF1B5E20)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header de la tarjeta
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.agriculture, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cred['cardTitle'] ?? "ID Ganadero",
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            Text(
                              cred['headerName'] ?? "NOMBRE",
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Imagen central / Hero
                if (cred['logoUrl'] != null)
                  Container(
                    height: 120,
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 0),
                    child: Image.network(
                      cred['logoUrl'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.white10),
                    ),
                  ),

                // Footer de la tarjeta con QR mockup
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("CLAVE UPP", style: TextStyle(color: Colors.white70, fontSize: 10)),
                          Text(cred['barcodeValue'] ?? "Cargando...", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.qr_code, size: 40, color: Colors.black87),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),

          // BOTON DE GOOGLE WALLET
          InkWell(
            onTap: () => _addToGoogleWallet(cred['id']),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/f/f2/Google_Wallet_logo_2022.svg',
                    height: 20,
                    errorBuilder: (_, __, ___) => const Icon(Icons.wallet, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Agregar a Google Wallet",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 10),
          const Text(
            "Disponible para Android",
            style: TextStyle(fontSize: 10, color: Colors.grey),
          )
        ],
      ),
    );
  }
}
