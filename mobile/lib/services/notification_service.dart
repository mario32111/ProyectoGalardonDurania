import 'dart:convert';
import 'package:flutter/material.dart';
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
        // Manejar click en la notificación cuando la app está abierta
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
  }

  /// Registra el token FCM del dispositivo en el backend.
  Future<void> registerToken() async {
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
    final notification = message.notification;
    final android = message.notification?.android;
    final data = message.data;

    if (notification != null) {
      // Mapeo de colores basado en el tipo
      // 'critico', 'advertencia', 'info', 'general'
      int colorValue = 0xFF01579B; // Azul default
      if (data['tipo'] == 'critico') colorValue = 0xFFF44336;
      if (data['tipo'] == 'advertencia') colorValue = 0xFFFF9800;
      if (data['tipo'] == 'info') colorValue = 0xFF4CAF50;

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
            icon: '@mipmap/ic_launcher',
            color: Color(colorValue),
          ),
        ),
        payload: jsonEncode(data),
      );
    }
  }
}
