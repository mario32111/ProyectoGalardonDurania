class EnvConfig {
  /// Cambiar a true para producción, false para desarrollo.
  static const bool isProduction = false;

  /// URL del servidor en producción (Azure).
  static const String prodUrl = 'https://backend-main.politepebble-de41f15a.westus.azurecontainerapps.io';
  
  /// URL del servidor en desarrollo (IP local).
  static const String devUrl = 'http://192.168.1.72:3000';

  /// Obtiene la URL del servidor según el entorno actual.
  static String get serverUrl => isProduction ? prodUrl : devUrl;
}
