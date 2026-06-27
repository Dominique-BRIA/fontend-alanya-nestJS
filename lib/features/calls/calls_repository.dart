import '../../core/authed_api.dart';
import '../../models/call_record.dart';
import 'webrtc_peer_session.dart';

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

  Future<List<CallRecord>> history() async {
    final data = await _api.get("/api/calls");
    return ((data["calls"] as List?) ?? [])
        .map((c) => CallRecord.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<StartedCall> start(String convId, String type) async {
    final data = await _api.post("/api/calls", {"convId": convId, "type": type});
    final callees = ((data["callees"] as List?) ?? [])
        .map((c) {
          final m = c as Map<String, dynamic>;
          return CallCallee(
            userId: m["userId"] as String,
            pseudo: m["pseudo"] as String?,
            publicNumber: m["publicNumber"] as String?,
          );
        })
        .toList();
    return StartedCall(
      id: data["id"] as String,
      convId: data["convId"] as String,
      type: data["type"] as String,
      callerName: data["callerName"] as String? ?? "Moi",
      isGroup: (data["isGroup"] as bool?) ?? false,
      groupName: data["groupName"] as String?,
      memberCount: (data["memberCount"] as num?)?.toInt() ?? 2,
      callees: callees,
    );
  }

  Future<AcceptCallResult> accept(String callId) async {
    final data = await _api.post("/api/calls/$callId/accept", {});
    final parts = ((data["activeParticipants"] as List?) ?? [])
        .map((p) => CallParticipantInfo.fromJson(p as Map<String, dynamic>))
        .toList();
    return AcceptCallResult(
      id: data["id"] as String,
      isGroup: (data["isGroup"] as bool?) ?? false,
      groupName: data["groupName"] as String?,
      activeParticipants: parts,
    );
  }

  Future<void> reject(String callId) async {
    await _api.post("/api/calls/$callId/reject", {});
  }

  Future<void> end(String callId) async {
    await _api.post("/api/calls/$callId/end", {});
  }

  Future<void> leave(String callId) async {
    await _api.post("/api/calls/$callId/leave", {});
  }

  Future<List<Map<String, dynamic>>> iceServers() async {
    try {
      final data = await _api.get("/api/calls/ice");
      final list = (data["iceServers"] as List?) ?? [];
      
      final safeServers = <Map<String, dynamic>>[];
      for (final e in list) {
        final map = Map<String, dynamic>.from(e as Map);
        
        // flutter_webrtc est très capricieux sur les clés "url" / "urls"
        // et peut crasher nativement (C++/Java) s'il y a des paramètres complexes
        String? targetUrl;
        if (map.containsKey('urls')) {
          final urls = map['urls'];
          targetUrl = urls is List ? urls.first.toString() : urls.toString();
        } else if (map.containsKey('url')) {
          targetUrl = map['url'].toString();
        }
        
        if (targetUrl != null) {
          // Retire les query params comme ?transport=tcp qui font parfois crasher le plugin natif
          if (targetUrl.contains('?')) {
            targetUrl = targetUrl.split('?').first;
          }
          
          safeServers.add({
            'url': targetUrl,
            'urls': [targetUrl], // On met les deux pour maximiser la compatibilité selon la plateforme
            if (map.containsKey('username')) 'username': map['username'],
            if (map.containsKey('credential')) 'credential': map['credential'],
          });
        }
      }
      return safeServers.isNotEmpty ? safeServers : WebrtcPeerSession.fallbackIce;
    } catch (e) {
      return WebrtcPeerSession.fallbackIce;
    }
  }
}
