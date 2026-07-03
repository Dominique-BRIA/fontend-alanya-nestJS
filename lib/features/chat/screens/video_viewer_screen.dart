import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/downloader.dart';
import '../../theme/app_theme.dart';

/// Visionneuse vidéo plein écran (style WhatsApp).
/// - Lecture/pause au tap
/// - Barre de progression
/// - Bouton télécharger
/// - Plein écran
class VideoViewerScreen extends StatefulWidget {
  const VideoViewerScreen({
    super.key,
    required this.videoUrl,
    required this.downloadUrl,
    required this.filename,
  });

  final String videoUrl;
  final String downloadUrl;
  final String filename;

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _showControls = true;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    _ctrl.initialize().then((_) {
      if (mounted) {
        setState(() => _initialized = true);
        _ctrl.play();
        _ctrl.setLooping(false);
      }
    });
    _ctrl.addListener(_listener);
  }

  void _listener() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_listener);
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _download() async {
    setState(() => _downloading = true);
    final path = await download(widget.downloadUrl, widget.filename);
    setState(() => _downloading = false);
    if (!mounted) return;
    if (path != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vidéo sauvegardée dans SewaChat/Videos/'),
          backgroundColor: AppColors.forest,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Échec du téléchargement'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _showControls
          ? AppBar(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
              title: Text(widget.filename, style: const TextStyle(fontSize: 14)),
              actions: [
                IconButton(
                  icon: _downloading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download),
                  onPressed: _downloading ? null : _download,
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Center(
          child: _initialized
              ? Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _ctrl.value.aspectRatio,
                      child: VideoPlayer(_ctrl),
                    ),
                    if (_showControls) _controlsBar(),
                  ],
                )
              : const CircularProgressIndicator(color: Colors.white),
        ),
      ),
    );
  }

  Widget _controlsBar() {
    final position = _ctrl.value.position;
    final duration = _ctrl.value.duration;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouton play/pause
        IconButton(
          icon: Icon(
            _ctrl.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
            color: Colors.white,
            size: 56,
          ),
          onPressed: () {
            setState(() {
              _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
            });
          },
        ),
        const SizedBox(height: 8),
        // Barre de progression
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Text(_fmtDuration(position), style: const TextStyle(color: Colors.white, fontSize: 12)),
              Expanded(
                child: VideoProgressIndicator(
                  _ctrl,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: AppColors.terracotta,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
              Text(_fmtDuration(duration), style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
