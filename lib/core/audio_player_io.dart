import 'dart:io';

import 'package:audioplayers/audioplayers.dart';

/// Lecture audio : lecteur intégré sur mobile, lecteur système sur desktop.
class InlineAudioPlayer {
  static AudioPlayer? _player;

  static Future<void> play(String url) async {
    stop();
    if (Platform.isAndroid || Platform.isIOS) {
      _player = AudioPlayer();
      await _player!.play(UrlSource(url));
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

  static void stop() {
    _player?.stop();
    _player?.dispose();
    _player = null;
  }
}
