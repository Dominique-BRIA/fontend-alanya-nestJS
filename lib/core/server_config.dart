import 'package:flutter/foundation.dart';

class ServerConfig {
  // URL de l'API REST (NestJS)
  // En dev : http://localhost:3000/api
  // En prod : https://api.alanya.app/api
  static const String apiBase = String.fromEnvironment(
    'API_URL',
    defaultValue: kReleaseMode 
      ? 'https://api.alanya.app/api' 
      : 'http://localhost:3000/api',
  );

  // URL du serveur WebSocket (Socket.io)
  // En dev : http://localhost:3000
  // En prod : wss://api.alanya.app (Socket.io gère le upgrade HTTP→WS)
  static const String wsBase = String.fromEnvironment(
    'WS_URL',
    defaultValue: kReleaseMode 
      ? 'wss://api.alanya.app' 
      : 'http://localhost:3000',
  );
}