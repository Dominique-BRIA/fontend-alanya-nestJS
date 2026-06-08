import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

/// Demande micro (+ caméra si vidéo) avant un appel. Sur web, le navigateur gère les permissions.
Future<bool> ensureCallPermissions({required bool video}) async {
  if (kIsWeb) return true;

  final mic = await Permission.microphone.request();
  if (!mic.isGranted) return false;

  if (video) {
    final cam = await Permission.camera.request();
    if (!cam.isGranted) return false;
  }
  return true;
}
