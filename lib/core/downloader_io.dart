import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

/// Mobile : ouvre l'URL de téléchargement dans le navigateur / gestionnaire.
/// Desktop : ouvre avec le gestionnaire système.
Future<void> downloadUrl(String url, String filename) async {
  final uri = Uri.parse(url);
  if (Platform.isAndroid || Platform.isIOS) {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return;
  }
  try {
    if (Platform.isLinux) {
      await Process.run("xdg-open", [url]);
    } else if (Platform.isMacOS) {
      await Process.run("open", [url]);
    } else if (Platform.isWindows) {
      await Process.run("cmd", ["/c", "start", "", url]);
    }
  } catch (_) {}
}
