import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/env_config.dart';

class ReportesService {
  static final ReportesService _instance = ReportesService._internal();
  factory ReportesService() => _instance;
  ReportesService._internal();

  /// Obtiene el historial individual de un animal por arete (SINIIGA)
  Future<Map<String, dynamic>?> obtenerHistorialIndividual(String arete) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final token = await user.getIdToken();
      final url = Uri.parse('${EnvConfig.serverUrl}/reportes/ganado/individual/$arete');
      
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print("Error obtenerHistorialIndividual: $e");
      return null;
    }
  }

  /// Obtiene el reporte agregado de compras, ventas y salud
  Future<Map<String, dynamic>?> obtenerReporteLotes({String? upp}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final token = await user.getIdToken();
      String uriStr = '${EnvConfig.serverUrl}/reportes/ganado/lotes';
      if (upp != null && upp.isNotEmpty) {
        uriStr += '?upp=$upp';
      }
      final url = Uri.parse(uriStr);
      
      final response = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'];
        }
      }
      return null;
    } catch (e) {
      print("Error obtenerReporteLotes: $e");
      return null;
    }
  }
}
