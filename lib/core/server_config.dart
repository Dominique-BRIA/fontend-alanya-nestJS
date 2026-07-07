import 'package:flutter/foundation.dart';

class ServerConfig {
  // URL du backend Next.js (Vercel)
  // On force l'URL de production même en Debug pour pouvoir tester sur des vrais téléphones.
  static const String apiBase = String.fromEnvironment(
    'API_URL',
    defaultValue: "https://backend-alanya.vercel.app",
  );

  // URL du serveur WebSocket (Render)
  // On force l'URL WSS de production même en Debug pour que les appels WebRTC fonctionnent sur des vrais téléphones.
  static const String wsBase = String.fromEnvironment(
    'WS_URL',
    defaultValue: "wss://alanya-ws.onrender.com",
  );
}
