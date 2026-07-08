import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ChangeNotifier, debugPrint;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'debug_overlay.dart';
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
  bool _connecting = false;
  bool _disposed = false;

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
      DebugOverlay.log("WS → connexion à $_wsUrl");
      final channel = WebSocketChannel.connect(Uri.parse("$_wsUrl?token=$token"));
      await channel.ready; // lève une exception si la connexion échoue
      _channel = channel;
      _connecting = false;
      _setConnected(true);
      DebugOverlay.log("WS ✅ CONNECTÉ");
      _sub = channel.stream.listen(
        _onData,
        onDone: _handleDrop,
        onError: (e) {
          DebugOverlay.log("WS ⚠️ err: $e");
          _handleDrop();
        },
        cancelOnError: true,
      );
    } catch (e) {
      DebugOverlay.log("WS ❌ échec: $e");
      _connecting = false;
      _setConnected(false);
      _scheduleReconnect();
    }
  }

  void _onData(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is Map<String, dynamic>) {
        final type = decoded["type"];
        DebugOverlay.log("WS ⬇️ $type");
        if (type == "incoming_call") {
          DebugOverlay.log("📞 INCOMING_CALL reçu !");
          debugPrint("[RealtimeClient] Trame incoming_call reçue du serveur !");
        }
        _controller.add(decoded);
      } else {
        DebugOverlay.log("WS ⬇️ (non-map)");
      }
    } catch (e) {
      DebugOverlay.log("WS ⬇️ ❌ non-JSON: $e");
    }
  }

  void _handleDrop() {
    DebugOverlay.log("WS 🔌 déconnecté (drop)");
    _setConnected(false);
    _sub?.cancel();
    _sub = null;
    _channel = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), connect);
  }

  void _setConnected(bool v) {
    if (connected == v) return;
    connected = v;
    notifyListeners();
  }

  void _send(Map<String, dynamic> payload) {
    final ch = _channel;
    if (ch == null || !connected) return;
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
