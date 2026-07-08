import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Connexion WebRTC vers un seul pair (utilisée par le mesh de groupe).
class WebrtcPeerSession {
  WebrtcPeerSession({
    required this.peerId,
    required this.isVideo,
    required this.isOfferer,
    required this.localStream,
    required this.iceServers,
    required this.onSendSignal,
    required this.onUpdated,
  });

  final String peerId;
  final bool isVideo;
  final bool isOfferer;
  final MediaStream localStream;
  final List<Map<String, dynamic>> iceServers;
  final void Function(Map<String, dynamic> signal) onSendSignal;
  final VoidCallback onUpdated;

  RTCPeerConnection? _pc;
  MediaStream? _remote;
  bool _started = false;
  bool _remoteReady = false;
  final _pendingSignals = <Map<String, dynamic>>[];
  final _iceQueue = <RTCIceCandidate>[];

  MediaStream? get remoteStream => _remote;
  bool get mediaConnected => _remote != null;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    final servers = iceServers.isNotEmpty ? iceServers : WebrtcPeerSession.fallbackIce;
    _pc = await createPeerConnection({"iceServers": servers});
    _pc!.onIceCandidate = (RTCIceCandidate? c) {
      if (c == null) return;
      onSendSignal({"kind": "ice", "candidate": c.toMap()});
    };
    _pc!.onTrack = (RTCTrackEvent e) {
      if (e.streams.isNotEmpty) {
        _remote = e.streams.first;
        onUpdated();
      }
    };

    for (final track in localStream.getTracks()) {
      await _pc!.addTrack(track, localStream);
    }

    if (isOfferer) {
      await _createOffer();
    }
    await _flushPendingSignals();
  }

  static const fallbackIce = [
    {
      "urls": [
        "stun:open.alanya.cloud:3478",
        "turn:open.alanya.cloud:3478?transport=tcp",
      ],
      "username": "alanya", // identifiants générés par le dashboard Metered
      "credential": "alanya2026",
    },
  ];

  Future<void> handleSignal(Map<String, dynamic> signal) async {
    if (!_started) {
      _pendingSignals.add(signal);
      return;
    }
    await _applySignal(signal);
  }

  Future<void> _createOffer() async {
    final pc = _pc;
    if (pc == null) return;
    final offer = await pc.createOffer({
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": isVideo,
      },
      "optional": [],
    });
    await pc.setLocalDescription(offer);
    onSendSignal({"kind": "offer", "sdp": offer.sdp, "type": offer.type});
  }

  Future<void> _applySignal(Map<String, dynamic> signal) async {
    final pc = _pc;
    if (pc == null) return;
    final kind = signal["kind"] as String?;

    if (kind == "offer") {
      final sdp = signal["sdp"] as String?;
      if (sdp == null) return;
      final type = signal["type"] as String? ?? "offer";
      await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
      _remoteReady = true;
      await _flushIceQueue();
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      onSendSignal({"kind": "answer", "sdp": answer.sdp, "type": answer.type});
    } else if (kind == "answer") {
      final sdp = signal["sdp"] as String?;
      if (sdp == null) return;
      final type = signal["type"] as String? ?? "answer";
      await pc.setRemoteDescription(RTCSessionDescription(sdp, type));
      _remoteReady = true;
      await _flushIceQueue();
    } else if (kind == "ice") {
      final raw = signal["candidate"];
      if (raw is! Map) return;
      final cand = RTCIceCandidate(
        raw["candidate"] as String?,
        raw["sdpMid"] as String?,
        raw["sdpMLineIndex"] as int?,
      );
      if (_remoteReady) {
        await pc.addCandidate(cand);
      } else {
        _iceQueue.add(cand);
      }
    }
  }

  Future<void> _flushPendingSignals() async {
    final copy = List<Map<String, dynamic>>.from(_pendingSignals);
    _pendingSignals.clear();
    for (final s in copy) {
      await _applySignal(s);
    }
  }

  Future<void> _flushIceQueue() async {
    final pc = _pc;
    if (pc == null) return;
    for (final c in List<RTCIceCandidate>.from(_iceQueue)) {
      await pc.addCandidate(c);
    }
    _iceQueue.clear();
  }

  Future<void> close() async {
    _remote = null;
    await _pc?.close();
    _pc = null;
    _started = false;
    _remoteReady = false;
    _pendingSignals.clear();
    _iceQueue.clear();
  }
}
