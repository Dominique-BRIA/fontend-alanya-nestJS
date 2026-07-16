import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'token_storage.dart';

/// Service WebSocket pour le temps réel (Socket.io).
/// Remplace l'ancien WebSocket natif par socket_io_client.
class SocketService {
  SocketService._internal(this._storage);
  
  final TokenStorage _storage;
  
  IO.Socket? _socket;
  bool _isConnected = false;
  String? _currentUserId;
  
  // Stream controllers pour les événements
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageReadController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingStartController = StreamController<Map<String, dynamic>>.broadcast();
  final _typingStopController = StreamController<Map<String, dynamic>>.broadcast();
  final _userStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _callIncomingController = StreamController<Map<String, dynamic>>.broadcast();
  final _callSignalController = StreamController<Map<String, dynamic>>.broadcast();
  final _callUpdateController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusNewController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusViewedController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  // Getters pour les streams
  Stream<Map<String, dynamic>> get onMessageNew => _messageController.stream;
  Stream<Map<String, dynamic>> get onMessageRead => _messageReadController.stream;
  Stream<Map<String, dynamic>> get onTypingStart => _typingStartController.stream;
  Stream<Map<String, dynamic>> get onTypingStop => _typingStopController.stream;
  Stream<Map<String, dynamic>> get onUserStatus => _userStatusController.stream;
  Stream<Map<String, dynamic>> get onCallIncoming => _callIncomingController.stream;
  Stream<Map<String, dynamic>> get onCallSignal => _callSignalController.stream;
  Stream<Map<String, dynamic>> get onCallUpdate => _callUpdateController.stream;
  Stream<Map<String, dynamic>> get onStatusNew => _statusNewController.stream;
  Stream<Map<String, dynamic>> get onStatusViewed => _statusViewedController.stream;
  Stream<bool> get onConnectionStateChanged => _connectionStateController.stream;

  bool get isConnected => _isConnected;

  /// Initialise et connecte le socket.
  Future<void> connect() async {
    if (_isConnected && _socket != null) return;
    
    final token = await _storage.accessToken;
    if (token == null) throw Exception('No access token available');

    // URL WebSocket depuis la config
    const wsUrl = 'http://localhost:3000'; // TODO: utiliser ServerConfig.wsBase
    
    _socket = IO.io(wsUrl, <String, dynamic>{
      'transports': ['websocket', 'polling'],
      'auth': {'token': token},
      'autoConnect': true,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 1000,
      'reconnectionDelayMax': 5000,
      'timeout': 20000,
      'forceNew': false,
    });

    _socket!.onConnect((_) {
      _isConnected = true;
      _connectionStateController.add(true);
      print('[Socket] Connected: ${_socket!.id}');
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      _connectionStateController.add(false);
      print('[Socket] Disconnected');
    });

    _socket!.onConnectError((error) {
      print('[Socket] Connection error: $error');
    });

    _socket!.onError((error) {
      print('[Socket] Error: $error');
    });

    // Événements métier
    _socket!.on('message:new', (data) => _messageController.add(Map<String, dynamic>.from(data)));
    _socket!.on('message:read', (data) => _messageReadController.add(Map<String, dynamic>.from(data)));
    _socket!.on('typing:start', (data) => _typingStartController.add(Map<String, dynamic>.from(data)));
    _socket!.on('typing:stop', (data) => _typingStopController.add(Map<String, dynamic>.from(data)));
    _socket!.on('user:status', (data) => _userStatusController.add(Map<String, dynamic>.from(data)));
    _socket!.on('call:incoming', (data) => _callIncomingController.add(Map<String, dynamic>.from(data)));
    _socket!.on('call:signal', (data) => _callSignalController.add(Map<String, dynamic>.from(data)));
    _socket!.on('call:update', (data) => _callUpdateController.add(Map<String, dynamic>.from(data)));
    _socket!.on('status:new', (data) => _statusNewController.add(Map<String, dynamic>.from(data)));
    _socket!.on('status:viewed', (data) => _statusViewedController.add(Map<String, dynamic>.from(data)));

    // Attendre la connexion
    await _waitForConnection();
  }

  Future<void> _waitForConnection() async {
    if (_isConnected) return;
    await _connectionStateController.stream.firstWhere((connected) => connected);
  }

  /// Rejoint une conversation pour recevoir ses messages temps réel.
  void joinConversation(String conversationId) {
    _socket?.emit('conversation:join', {'conversationId': conversationId});
  }

  /// Quitte une conversation.
  void leaveConversation(String conversationId) {
    _socket?.emit('conversation:leave', {'conversationId': conversationId});
  }

  /// Envoie un message texte.
  void sendMessage({
    required String conversationId,
    required String content,
    String type = 'text',
    String? mediaId,
  }) {
    _socket?.emit('message:send', {
      'conversationId': conversationId,
      'content': content,
      'type': type,
      if (mediaId != null) 'mediaId': mediaId,
    });
  }

  /// Marque un message comme lu.
  void markMessageRead(String conversationId, String messageId) {
    _socket?.emit('message:read', {
      'conversationId': conversationId,
      'messageId': messageId,
    });
  }

  /// Indique qu'on est en train d'écrire.
  void startTyping(String conversationId) {
    _socket?.emit('typing:start', {'conversationId': conversationId});
  }

  /// Indique qu'on a arrêté d'écrire.
  void stopTyping(String conversationId) {
    _socket?.emit('typing:stop', {'conversationId': conversationId});
  }

  /// Signalisation WebRTC (SDP/ICE).
  void sendCallSignal({
    required String callId,
    required String targetUserId,
    required Map<String, dynamic> signal,
  }) {
    _socket?.emit('call:signal', {
      'callId': callId,
      'targetUserId': targetUserId,
      'signal': signal,
    });
  }

  /// Déconnexion propre.
  Future<void> disconnect() async {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
    
    await _messageController.close();
    await _messageReadController.close();
    await _typingStartController.close();
    await _typingStopController.close();
    await _userStatusController.close();
    await _callIncomingController.close();
    await _callSignalController.close();
    await _callUpdateController.close();
    await _statusNewController.close();
    await _statusViewedController.close();
    await _connectionStateController.close();
  }
  
  /// Singleton pattern
  static SocketService? _instance;
  static TokenStorage? _storageInstance;
  
  static SocketService getInstance(TokenStorage storage) {
    _storageInstance = storage;
    _instance ??= SocketService._internal(storage);
    return _instance!;
  }
  
  static void disposeInstance() {
    _instance?.disconnect();
    _instance = null;
  }
}