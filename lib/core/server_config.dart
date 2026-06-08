import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// URLs du backend — configurables pour mobile (émulateur vs téléphone réel).
///
/// Appareil physique sur le même Wi-Fi que ton PC :
///   flutter run --dart-define=API_HOST=192.168.1.XX
///
/// Émulateur Android : 10.0.2.2 (défaut). Simulateur iOS : localhost.
class ServerConfig {
  static const String _hostOverride = String.fromEnvironment("API_HOST");
  static const int apiPort = int.fromEnvironment("API_PORT", defaultValue: 3000);
  static const int wsPort = int.fromEnvironment("WS_PORT", defaultValue: 3001);

  static String get host {
    if (_hostOverride.isNotEmpty) return _hostOverride;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return "10.0.2.2"; // émulateur Android → machine hôte
    }
    return "localhost"; // web, iOS simulateur, desktop
  }

  static String get apiBase => "http://$host:$apiPort";
  static String get wsBase => "ws://$host:$wsPort";
}
