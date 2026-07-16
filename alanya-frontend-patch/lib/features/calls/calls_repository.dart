import '../../core/authed_api.dart';
import '../../models/call_record.dart';

class CallCallee {
  final String userId;
  final String? pseudo;
  final String? publicNumber;

  CallCallee({required this.userId, required this.pseudo, required this.publicNumber});
}

class StartedCall {
  final String id;
  final String convId;
  final String type;
  final String callerName;
  final bool isGroup;
  final String? groupName;
  final int memberCount;
  final List<CallCallee> callees;

  StartedCall({
    required this.id,
    required this.convId,
    required this.type,
    required this.callerName,
    required this.isGroup,
    required this.groupName,
    required this.memberCount,
    required this.callees,
  });
}

class AcceptCallResult {
  final String id;
  final bool isGroup;
  final String? groupName;
  final List<CallParticipantInfo> activeParticipants;

  AcceptCallResult({
    required this.id,
    required this.isGroup,
    required this.groupName,
    required this.activeParticipants,
  });
}

class CallsRepository {
  CallsRepository(this._api);

  final AuthedApi _api;

  /// Historique des appels.
  /// ✅ NOUVEAU : GET /api/calls (paginé)
  Future<CallHistoryResult> history({int limit = 20, String? cursor}) async {
    String path = '/api/calls?limit=$limit';
    if (cursor != null) path += '&cursor=$cursor';
    final data = await _api.get(path);
    
    final calls = ((data['calls'] as List?) ?? [])
        .map((c) => CallRecord.fromJson(c as Map<String, dynamic>))
        .toList();
    
    return CallHistoryResult(
      calls: calls,
      nextCursor: data['nextCursor'] as String?,
    );
  }

  /// Démarre un appel (audio/video).
  /// ✅ NOUVEAU : POST /api/calls/initiate avec { conversationId, type, targetUserId }
  Future<StartedCall> start(String convId, String type, String targetUserId) async {
    final data = await _api.post('/api/calls/initiate', {
      'conversationId': convId,
      'type': type, // 'audio' ou 'video'
      'targetUserId': targetUserId,
    });

    final callees = ((data['callees'] as List?) ?? [])
        .map((c) {
          final m = c as Map<String, dynamic>;
          return CallCallee(
            userId: m['userId'] as String,
            pseudo: m['pseudo'] as String?,
            publicNumber: m['publicNumber'] as String?,
          );
        })
        .toList();

    return StartedCall(
      id: data['id'] as String,
      convId: data['conversationId'] as String,
      type: data['type'] as String,
      callerName: data['callerName'] as String? ?? 'Moi',
      isGroup: (data['isGroup'] as bool?) ?? false,
      groupName: data['groupName'] as String?,
      memberCount: (data['memberCount'] as num?)?.toInt() ?? 2,
      callees: callees,
    );
  }

  /// Accepte un appel entrant.
  /// ✅ NOUVEAU : PUT /api/calls/action avec action: 'accept'
  Future<AcceptCallResult> accept(String callId) async {
    final data = await _api.put('/api/calls/action', {
      'callId': callId,
      'action': 'accept',
    });

    final parts = ((data['activeParticipants'] as List?) ?? [])
        .map((p) => CallParticipantInfo.fromJson(p as Map<String, dynamic>))
        .toList();

    return AcceptCallResult(
      id: data['id'] as String,
      isGroup: (data['isGroup'] as bool?) ?? false,
      groupName: data['groupName'] as String?,
      activeParticipants: parts,
    );
  }

  /// Rejette un appel.
  Future<void> reject(String callId) async {
    await _api.put('/api/calls/action', {
      'callId': callId,
      'action': 'decline',
    });
  }

  /// Termine un appel (initiateur).
  Future<void> end(String callId) async {
    await _api.put('/api/calls/action', {
      'callId': callId,
      'action': 'end',
    });
  }

  /// Quitte un appel (participant).
  Future<void> leave(String callId) async {
    await _api.put('/api/calls/action', {
      'callId': callId,
      'action': 'end', // Même action pour quitter
    });
  }

  /// Envoie un signal WebRTC (SDP/ICE).
  /// ✅ NOUVEAU : Via WebSocket gateway (call:signal)
  /// Cette méthode est gardée pour compatibilité mais le signal passe par WebSocket.
  Future<void> sendSignal(String callId, String targetUserId, Map<String, dynamic> signal) async {
    // Le signal WebRTC passe maintenant par WebSocket (EventsGateway)
    // Cette méthode REST n'existe plus dans NestJS
    throw UnimplementedError('WebRTC signaling now goes through WebSocket gateway');
  }

  /// Récupère les serveurs ICE (STUN/TURN).
  /// ❌ Endpoint manquant dans NestJS - à ajouter ou configurer côté client
  Future<List<Map<String, dynamic>>> iceServers() async {
    // TODO: Backend endpoint /api/calls/ice manquant
    // Pour l'instant, retourner config par défaut
    return [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun.cloudflare.com:3478'},
    ];
  }

  /// Détail d'un appel.
  Future<Map<String, dynamic>> getCall(String callId) async {
    return _api.get('/api/calls/$callId');
  }
}

/// Résultat paginé pour l'historique des appels.
class CallHistoryResult {
  final List<CallRecord> calls;
  final String? nextCursor;

  CallHistoryResult({required this.calls, this.nextCursor});
}