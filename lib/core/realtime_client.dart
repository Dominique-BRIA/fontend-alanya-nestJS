import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'server_config.dart';
import 'token_storage.dart';

/// Client WebSocket temps réel : connexion authentifiée, reconnexion auto,
/// flux d'événements diffusé et envoi de messages / accusés / « typing ».
class RealtimeClient extends ChangeNotifier {
  RealtimeClient(this._storage, {String? wsUrl}) : _wsUrl = wsUrl ?? _defaultWsUrl;

  final TokenStorage _storage;
  final String _wsUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _connecting = false;
  bool _disposed = false;
  int _reconnectAttempt = 0;

  // Queue des trames à envoyer quand la WS n'est pas encore ouverte.
  // Évite qu'un appel _send() effectué juste après connect() soit perdu
  // silencieusement (cas typique de startOutgoing → callRing).
  final List<Map<String, dynamic>> _pendingOut = [];

  bool connected = false;

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _controller.stream;

  static String get _defaultWsUrl => ServerConfig.wsBase;

  Future<void> connect() async {
    if (_disposed || _connecting || connected) return;
    _connecting = true;
    final token = await _storage.accessToken;
    if (token == null) {
      _connecting = false;
      return;
    }
    try {
      debugPrint("[RealtimeClient] Tentative de connexion à $_wsUrl ...");
      final channel = WebSocketChannel.connect(Uri.parse("$_wsUrl?token=$token"));
      await channel.ready; // lève une exception si la connexion échoue
      _channel = channel;
      _connecting = false;
      _reconnectAttempt = 0;
      _setConnected(true);
      debugPrint("[RealtimeClient] ✅ Connecté");
      _sub = channel.stream.listen(
        _onData,
        onDone: _handleDrop,
        onError: (e) {
          debugPrint("[RealtimeClient] Erreur stream: $e");
          _handleDrop();
        },
        // FIX: cancelOnError:true tuait la subscription à la moindre trame
        // douteuse. On préfère loguer et continuer.
        cancelOnError: false,
      );
      // Flushe les trames mises en attente pendant la déconnexion.
      _flushPending();
      // Démarre un ping applicatif pour détecter les sockets fantômes
      // derrière les NAT mobiles (WiFi/4G).
      _startPing();
    } catch (e) {
      debugPrint("[RealtimeClient] ❌ Connexion échouée: $e");
      _connecting = false;
      _setConnected(false);
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    try {
      // Log de diagnostic : permet de vérifier que la trame arrive bien.
      final preview = raw.toString();
      debugPrint("[RealtimeClient] ⬇️ TRAME: ${preview.length > 200 ? preview.substring(0, 200) : preview}");
      final decoded = jsonDecode(raw as String);
      if (decoded is Map<String, dynamic>) {
        if (decoded["type"] == "incoming_call") {
          debugPrint("[RealtimeClient] 📞 Trame incoming_call reçue du serveur !");
        }
        _controller.add(decoded);
      }
    } catch (e) {
      debugPrint("[RealtimeClient] Trame non-JSON ignorée: $e");
    }
  }

  void _handleDrop() {
    debugPrint("[RealtimeClient] Connexion perdue, planification reconnexion...");
    _setConnected(false);
    _sub?.cancel();
    _sub = null;
    _channel = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    // Backoff exponentiel avec plafond : 1s, 2s, 4s, 8s, 16s, 30s max.
    final delaySec = (1 << _reconnectAttempt).clamp(1, 30);
    _reconnectAttempt = (_reconnectAttempt + 1).clamp(0, 5);
    debugPrint("[RealtimeClient] Reconnexion dans ${delaySec}s (tentative ${_reconnectAttempt})");
    _reconnectTimer = Timer(Duration(seconds: delaySec), connect);
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!connected) return;
      try {
        _channel?.sink.add(jsonEncode({"type": "ping"}));
      } catch (_) {}
    });
  }

  void _flushPending() {
    if (_pendingOut.isEmpty) return;
    debugPrint("[RealtimeClient] Flush de ${_pendingOut.length} trame(s) en attente");
    final copy = List<Map<String, dynamic>>.from(_pendingOut);
    _pendingOut.clear();
    for (final p in copy) {
      _send(p);
    }
  }

  void _setConnected(bool v) {
    if (connected == v) return;
    connected = v;
    notifyListeners();
  }

  void _send(Map<String, dynamic> payload) {
    final ch = _channel;
    if (ch == null || !connected) {
      // FIX: mise en file au lieu de perdre silencieusement la trame.
      // Sans ça, un callRing() lancé juste après connect() (WS pas encore
      // ouverte) est purement et simplement ignoré → B ne reçoit rien.
      // Plafond de sécurité pour éviter fuite mémoire.
      if (_pendingOut.length < 50) {
        _pendingOut.add(payload);
        debugPrint("[RealtimeClient] ⏳ WS pas prête, trame ${payload["type"]} mise en file (${_pendingOut.length})");
      }
      // Tente d'ouvrir la connexion si ce n'est pas déjà en cours.
      if (!_connecting && !connected) {
        connect();
      }
      return;
    }
    ch.sink.add(jsonEncode(payload));
  }

  void sendMessage(String convId, String content, String tempId, {String? replyToId}) =>
      _send({
        "type": "send",
        "convId": convId,
        "content": content,
        "msgType": "TEXT",
        "tempId": tempId,
        if (replyToId != null) "replyToId": replyToId,
      });

  void sendMedia(String convId, String mediaId, String msgType, String tempId, {String? replyToId}) => _send({
        "type": "send",
        "convId": convId,
        "mediaId": mediaId,
        "msgType": msgType,
        "tempId": tempId,
        if (replyToId != null) "replyToId": replyToId,
      });

  void markRead(String convId) => _send({"type": "read", "convId": convId});

  void deleteMessage(String messageId, {String scope = "me"}) =>
      _send({"type": "delete_message", "messageId": messageId, "scope": scope});

  void forwardMessage(String messageId, List<String> targetConvIds) =>
      _send({"type": "forward_message", "messageId": messageId, "targetConvIds": targetConvIds});

  void sendTyping(String convId, bool isTyping) =>
      _send({"type": "typing", "convId": convId, "isTyping": isTyping});

  void callRing(String callId) => _send({"type": "call_ring", "callId": callId});

  void callSignal(String callId, String toUserId, Map<String, dynamic> signal) =>
      _send({"type": "call_signal", "callId": callId, "toUserId": toUserId, "signal": signal});

  void callState(
    String callId,
    String state, {
    String? userId,
    String? displayName,
  }) =>
      _send({
        "type": "call_state",
        "callId": callId,
        "state": state,
        if (userId != null) "userId": userId,
        if (displayName != null) "displayName": displayName,
      });

  void disconnect() {
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _pingTimer = null;
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _sub = null;
    _setConnected(false);
  }

  @override
  void dispose() {
    _disposed = true;
    disconnect();
    _controller.close();
    super.dispose();
  }
}
