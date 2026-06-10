import 'package:flutter/foundation.dart';

class ServerConfig {
  // URL du backend Next.js (Vercel)
  static const String apiBase = String.fromEnvironment(
    'API_URL',
    defaultValue: kReleaseMode
        ? "https://backend-alanya.vercel.app"
        : "http://10.0.2.2:3000",
  );

  // URL du serveur WebSocket (Render)
  // En release, on force wss:// ; en debug, ws:// local sur l'émulateur Android.
  static const String wsBase = String.fromEnvironment(
    'WS_URL',
    defaultValue: kReleaseMode
        ? "wss://alanya-ws.onrender.com"
        : "ws://10.0.2.2:3001",
  );
}
