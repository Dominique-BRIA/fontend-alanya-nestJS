import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service de notifications locales.
///
/// Crée un canal de notification Android (obligatoire depuis Android 8+) et
/// demande la permission POST_NOTIFICATIONS (Android 13+). Sans canal, Android
/// bloque toutes les notifications et le toggle dans les paramètres est grisé.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Initialise le canal de notification et demande la permission.
  /// À appeler au démarrage de l'app (après le bootstrap d'auth).
  Future<void> tryInitialize() async {
    if (_initialized) return;

    try {
      // Configuration Android : crée le canal "messages".
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Crée explicitement le canal Android (obligatoire pour Android 8+).
      await _createChannel();

      // Demande la permission sur Android 13+.
      await _requestPermission();

      _initialized = true;
    } catch (e) {
      debugPrint('[PushService] Erreur initialisation: $e');
    }
  }

  /// Crée le canal de notification "messages" avec importance HIGH.
  Future<void> _createChannel() async {
    const channel = AndroidNotificationChannel(
      'messages',
      'Messages',
      description: 'Notifications des nouveaux messages et appels',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Demande la permission POST_NOTIFICATIONS (Android 13+).
  /// Sans ça, le toggle reste grisé dans les paramètres Android.
  Future<void> _requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      // Retourne false si l'utilisateur a déjà refusé — il devra aller dans les paramètres.
      await android.requestNotificationsPermission();
    }
    // iOS : la permission est demandée lors de l'initialisation.
  }

  /// Affiche une notification locale (message entrant, appel, etc.).
  Future<void> show({
    required String title,
    required String body,
    int id = 0,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) await tryInitialize();
    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'messages',
            'Messages',
            channelDescription: 'Notifications des nouveaux messages et appels',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: payload?.toString(),
      );
    } catch (e) {
      debugPrint('[PushService] Erreur affichage notification: $e');
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    debugPrint('[PushService] Notification tapée: ${response.payload}');
    // TODO : navigation vers la conversation concernée
  }

  Future<void> bindRepository(Object? repo) async {}

  Future<void> unregister() async {}
}
