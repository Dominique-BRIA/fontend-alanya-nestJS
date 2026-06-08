// ignore: deprecated_member_use
import 'dart:html' as html;

/// Lecteur audio minimal pour le web (une piste à la fois).
class InlineAudioPlayer {
  static html.AudioElement? _current;

  static Future<void> play(String url) async {
    stop();
    _current = html.AudioElement()
      ..src = url
      ..autoplay = true;
  }

  static void stop() {
    _current?.pause();
    _current = null;
  }
}
