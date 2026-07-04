import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../core/api_client.dart';
import '../core/token_storage.dart';

/// Service de notifications push complet (FCM + notifications locales).
///
/// - Initialise Firebase Messaging
/// - Demande la permission (iOS + Android 13+)
/// - Récupère le token FCM et l'enregistre auprès du backend
/// - Crée un canal de notification Android
/// - Affiche les notifications quand l'app est en premier plan (foreground)
/// - Gère le tap sur notification (navigation)
///
/// Les notifications en arrière-plan (app fermée) sont gérées automatiquement
/// par le système Android via FCM (pas besoin de code Dart).
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  final _localPlugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  ApiClient? _api;
  TokenStorage? _storage;

  /// Lie le service aux repositories (appelé au démarrage).
  Future<void> bindRepository(Object? repo) async {
    // On récupère l'api et le storage via le contexte global si nécessaire.
    // Pour cette implémentation, on les passe directement depuis main().
  }

  /// Initialise Firebase, les canaux de notification, et enregistre le token.
  Future<void> tryInitialize({ApiClient? api, TokenStorage? storage}) async {
    if (_initialized) return;

    _api = api;
    _storage = storage;

    try {
      // 1) Initialise Firebase Core
      await Firebase.initializeApp();

      // 2) Configure les notifications locales (canal Android)
      await _initLocalNotifications();

      // 3) Configure le callback d'arrière-plan (top-level function)
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

      // 4) Demande la permission
      await _requestPermission();

      // 5) Écoute les messages en foreground (app ouverte)
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // 6) Écoute le tap sur notification quand l'app était en arrière-plan
      FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      // 7) Récupère et enregistre le token FCM
      await _registerToken();

      // 8) Écoute les changements de token (refresh)
      FirebaseMessaging.instance.onTokenRefresh.listen((_) => _registerToken());

      _initialized = true;
      debugPrint('[PushService] Initialisé avec succès');
    } catch (e) {
      debugPrint('[PushService] Erreur initialisation: $e');
    }
  }

  /// Initialise les notifications locales (crée le canal Android).
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Crée le canal Android obligatoire (Android 8+)
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'messages',
        'Messages',
        description: 'Notifications des nouveaux messages et appels',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );
      await _localPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Demande la permission (Android 13+ POST_NOTIFICATIONS + iOS).
  Future<void> _requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[PushService] Permission: ${settings.authorizationStatus}');
  }

  /// Récupère le token FCM et l'enregistre auprès du backend.
  Future<void> _registerToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('[PushService] Token FCM null');
        return;
      }
      debugPrint('[PushService] Token FCM: $token');

      // Envoie le token au backend via POST /api/push/register
      if (_api != null && _storage != null) {
        final accessToken = await _storage!.accessToken;
        if (accessToken != null) {
          await _api!.post(
            '/api/push/register',
            {'token': token, 'platform': 'android'},
            bearer: accessToken,
          );
          debugPrint('[PushService] Token enregistré auprès du backend');
        }
      }
    } catch (e) {
      debugPrint('[PushService] Erreur enregistrement token: $e');
    }
  }

  /// Gère les messages reçus quand l'app est en premier plan (foreground).
  /// FCM n'affiche pas automatiquement la notification en foreground sur Android,
  /// il faut l'afficher manuellement via flutter_local_notifications.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('[PushService] Message foreground: ${message.notification?.title}');

    final notification = message.notification;
    if (notification == null) return;

    _localPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      notification.title ?? 'Alanya',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'messages',
          'Messages',
          channelDescription: 'Notifications des nouveaux messages et appels',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  /// Gère le tap sur une notification (ouverture de conversation).
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[PushService] Notification tapée: ${message.data}');
    _navigateFromPayload(message.data);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('[PushService] Notif locale tapée: ${response.payload}');
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateFromPayload(data);
      } catch (_) {}
    }
  }

  /// Navigation vers la conversation ou l'appel selon les données de la notif.
  void _navigateFromPayload(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final convId = data['convId'] as String?;

    if (convId != null && convId.isNotEmpty) {
      // TODO : navigation vers la conversation quand le système de routing sera en place
      debugPrint('[PushService] Navigation vers conv: $convId (type: $type)');
    }
  }

  /// Affiche une notification locale (pour les messages reçus via WebSocket
  /// quand l'app est en arrière-plan local).
  Future<void> show({
    required String title,
    required String body,
    int id = 0,
    Map<String, dynamic>? payload,
  }) async {
    await _localPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'messages',
          'Messages',
          channelDescription: 'Notifications des nouveaux messages et appels',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload?.toString(),
    );
  }

  /// Désenregistre le token FCM (à la déconnexion).
  Future<void> unregister() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && _api != null && _storage != null) {
        final accessToken = await _storage!.accessToken;
        if (accessToken != null) {
          await _api!.delete(
            '/api/push/register?token=$token',
            bearer: accessToken,
          );
        }
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('[PushService] Erreur unregister: $e');
    }
  }
}

/// Handler top-level pour les notifications en arrière-plan (app fermée).
/// Doit être une fonction top-level (pas une méthode de classe) et ne doit pas
/// capturer d'état. Android l'exécute dans un isolate séparé.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Initialise Firebase dans l'isolate d'arrière-plan
  await Firebase.initializeApp();

  debugPrint('[PushService] Message background: ${message.notification?.title}');

  // Sur Android, FCM affiche automatiquement la notification dans la barre système
  // quand l'app est en arrière-plan. On n'a rien à faire ici de plus.
}
