import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // <--- AGREGADO PARA kIsWeb
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as fln;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/env_config.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final fln.FlutterLocalNotificationsPlugin _localNotifications = fln.FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // En la web, las notificaciones fcm requieren configuración adicional (vapidKey, service worker).
    // Evitamos bloquear el arranque de la app si estamos en el navegador.
    if (kIsWeb) {
      print('🌐 Plataforma Web detectada: Saltando inicialización nativa de notificaciones.');
      _initialized = true;
      return;
    }

    try {
      // 1. Solicitar permisos (especialmente en iOS y Android 13+)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('🔔 Permisos de notificaciones concedidos');
      }

      // 2. Configurar notificaciones locales para Android (Foreground)
      const fln.AndroidInitializationSettings initializationSettingsAndroid =
          fln.AndroidInitializationSettings('@mipmap/ic_launcher');
      
      const fln.InitializationSettings initializationSettings = fln.InitializationSettings(
        android: initializationSettingsAndroid,
      );

      await _localNotifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          print('Notificación clickeada: ${details.payload}');
        },
      );

      // 3. Manejar mensajes en primer plano (Foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Mensaje recibido en primer plano: ${message.notification?.title}');
        _showLocalNotification(message);
      });

      // 4. Manejar apertura desde notificación (Background/Terminated)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('App abierta desde notificación: ${message.notification?.title}');
      });

      _initialized = true;
      
      // Intentar registrar el token si hay un usuario logueado
      await registerToken();
    } catch (e) {
      print('❌ Error inicializando NotificationService: $e');
    }
  }

  /// Registra el token FCM del dispositivo en el backend.
  Future<void> registerToken() async {
    if (kIsWeb) return; // Por ahora no registramos tokens en web sin vapidKey

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String? token = await _fcm.getToken();
      if (token == null) return;

      print('FCM Token: $token');

      final idToken = await user.getIdToken();
      final response = await http.post(
        Uri.parse('${EnvConfig.serverUrl}/notifications/register-token'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'token': token}),
      );

      if (response.statusCode == 200) {
        print('✅ Token registrado exitosamente en el backend');
      } else {
        print('❌ Error al registrar token: ${response.body}');
      }
    } catch (e) {
      print('❌ Excepción al registrar token: $e');
    }
  }

  /// Muestra una notificación local (usado para Foreground).
  void _showLocalNotification(RemoteMessage message) {
    if (kIsWeb) return;

    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      int colorValue = 0xFF01579B; // Azul default
      String iconName = 'ic_stat_default';

      if (data['tipo'] == 'critico') {
        colorValue = 0xFFF44336;
        iconName = 'ic_stat_critico';
      } else if (data['tipo'] == 'advertencia') {
        colorValue = 0xFFFF9800;
        iconName = 'ic_stat_warning';
      } else if (data['tipo'] == 'info') {
        colorValue = 0xFF4CAF50;
        iconName = 'ic_stat_info';
      }

      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        fln.NotificationDetails(
          android: fln.AndroidNotificationDetails(
            'high_importance_channel',
            'Sistemas de Alertas',
            channelDescription: 'Canal para alertas críticas del rancho',
            importance: fln.Importance.max,
            priority: fln.Priority.high,
            icon: iconName,
            color: Color(colorValue),
          ),
        ),
        payload: jsonEncode(data),
      );
    }
  }
}
