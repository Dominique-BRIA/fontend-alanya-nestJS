import 'package:flutter/foundation.dart';

class ServerConfig {
  // Ces valeurs sont injectées au moment de la compilation par Codemagic
  // Si rien n'est fourni, on utilise les valeurs par défaut (Production ou Dev)
  static const String apiBase = String.fromEnvironment(
    'API_URL',
    defaultValue: kReleaseMode 
        ? "https://backend-alanya.vercel.app" 
        : "http://10.0.2.2:3000",
  );

  static const String wsBase = String.fromEnvironment(
    'WS_URL',
    defaultValue: kReleaseMode 
        ? "wss://alanya-ws.onrender.com" 
        : "ws://10.0.2.2:3001",
  );
}
