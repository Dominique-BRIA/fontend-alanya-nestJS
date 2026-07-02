import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_client.dart';
import '../../../core/app_snackbar.dart';
import '../../../core/audio_player.dart';
import '../../../core/downloader.dart';
import '../../../core/realtime_client.dart';
import '../../../core/token_storage.dart';
import '../../../core/voice_recorder.dart';
import '../../../core/locale_controller.dart';
import '../../../core/translate_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/message.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/auth_network_image.dart';
import '../../../widgets/back_app_bar.dart';
import '../../../widgets/motif_background.dart';
import '../../auth/auth_controller.dart';
import '../../calls/call_controller.dart';
import '../../calls/screens/active_call_screen.dart';
import '../../media/media_repository.dart';
import '../chat_repository.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.convId,
    required this.title,
    this.isGroup = false,
    this.memberNames = const {},
  });
  final String convId;
  final String title;
  final bool isGroup;
  final Map<String, String> memberNames;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Message> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Timer? _pollTimer;
  StreamSubscription<Map<String, dynamic>>? _rtSub;
  String? _myId;
  String? _token;
  String _baseUrl = "";
  bool _uploading = false;
  final _voiceRecorder = VoiceRecorder();
  bool _recording = false;
  DateTime? _recordStarted;

  // --- Traduction ---
  final _translateService = TranslateService();
  final Map<String, String> _translations = {};
  final Set<String> _translating = {};

  @override
  void initState() {
    super.initState();
    _load();
    final rt = context.read<RealtimeClient>();
    rt.connect(); // au cas où la connexion ne serait pas encore ouverte
    _rtSub = rt.events.listen(_onRealtimeEvent);
    // Polling de repli : actif uniquement quand le WebSocket n'est pas connecté.
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _rtSub?.cancel();
    _voiceRecorder.cancel();
    _translateService.dispose();
    InlineAudioPlayer.stop();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Traite un événement temps réel concernant cette conversation.
  void _onRealtimeEvent(Map<String, dynamic> e) {
    if (!mounted) return;
    final type = e["type"];
    if (type == "message") {
      final data = e["message"] as Map<String, dynamic>?;
      if (data == null || data["convId"] != widget.convId) return;
      final msg = Message.fromJson(data);
      final tempId = e["tempId"] as String?;
      setState(() {
        // Réconcilie l'optimiste (par tempId) sinon ajoute si nouveau.
        final idx = tempId != null ? _messages.indexWhere((m) => m.id == tempId) : -1;
        if (idx >= 0) {
          _messages[idx] = msg;
        } else if (!_messages.any((m) => m.id == msg.id)) {
          _messages = [..._messages, msg];
        }
      });
      // Message entrant => marquer lu.
      if (msg.senderId != _myId) _markReadRemote();
      _scrollToBottom();
    } else if (type == "read") {
      if (e["convId"] != widget.convId) return;
      // L'autre a lu : passe mes messages à READ.
      setState(() {
        _messages = _messages
            .map((m) => m.senderId == _myId && m.status != "READ"
                ? Message(
                    id: m.id,
                    convId: m.convId,
                    senderId: m.senderId,
                    content: m.content,
                    type: m.type,
                    status: "READ",
                    replyToId: m.replyToId,
                    media: m.media,
                    createdAt: m.createdAt,
                  )
                : m)
            .toList();
      });
    }
  }

  void _markReadRemote() {
    final rt = context.read<RealtimeClient>();
    if (rt.connected) {
      rt.markRead(widget.convId);
    } else {
      context.read<ChatRepository>().markRead(widget.convId);
    }
  }

  Future<void> _load() async {
    try {
      _myId = context.read<AuthController>().user?.id;
      _baseUrl = context.read<ApiClient>().baseUrl;
      _token = await context.read<TokenStorage>().accessToken;
      final repo = context.read<ChatRepository>();
      final msgs = await repo.getMessages(widget.convId);
      if (!mounted) return;
      setState(() {
        _messages = msgs.reversed.toList(); // du plus ancien au plus récent
        _loading = false;
      });
      _markReadRemote();
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Récupère silencieusement l'état courant et fusionne s'il y a du nouveau.
  /// Repli uniquement : on saute si le temps réel est connecté.
  Future<void> _poll() async {
    if (!mounted || _loading) return;
    if (context.read<RealtimeClient>().connected) return;
    try {
      final repo = context.read<ChatRepository>();
      final latest = (await repo.getMessages(widget.convId)).reversed.toList();
      if (!mounted) return;
      if (_signature(latest) == _signature(_messages)) return; // rien de neuf

      final hadMore = latest.length > _messages.length;
      final atBottom = !_scrollCtrl.hasClients ||
          _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 60;
      setState(() => _messages = latest);
      // Un message entrant => on marque comme lu.
      if (hadMore) repo.markRead(widget.convId);
      if (hadMore && atBottom) _scrollToBottom();
    } catch (_) {
      // Erreurs réseau silencieuses : on retentera au prochain tick.
    }
  }

  /// Signature compacte (ids + statuts) pour détecter un changement réel.
  String _signature(List<Message> msgs) =>
      msgs.map((m) => "${m.id}:${m.status}").join("|");

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    final rt = context.read<RealtimeClient>();

    // Voie temps réel : envoi optimiste, réconcilié à l'écho du serveur.
    if (rt.connected) {
      final tempId = "tmp-${DateTime.now().microsecondsSinceEpoch}";
      final optimistic = Message(
        id: tempId,
        convId: widget.convId,
        senderId: _myId ?? "",
        content: text,
        type: "TEXT",
        status: "SENT",
        replyToId: null,
        media: const [],
        createdAt: DateTime.now(),
      );
      setState(() => _messages = [..._messages, optimistic]);
      _inputCtrl.clear();
      rt.sendMessage(widget.convId, text, tempId);
      _scrollToBottom();
      return;
    }

    // Repli REST si le WebSocket n'est pas disponible.
    setState(() => _sending = true);
    try {
      final msg = await context.read<ChatRepository>().sendText(widget.convId, text);
      _inputCtrl.clear();
      setState(() => _messages = [..._messages, msg]);
      _scrollToBottom();
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError(tr(context, 'send_failed'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendFile() async {
    if (_uploading) return;
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
    } catch (_) {
      if (mounted) {
        _showError(
          "Sélection de fichier indisponible sur Linux — installe zenity : sudo apt install zenity",
        );
      }
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    final mime = _mimeFromName(file.name);
    final msgType = mime.startsWith("image/")
        ? "IMAGE"
        : mime.startsWith("audio/")
            ? "AUDIO"
            : "FILE";
    await _uploadAndSend(bytes, file.name, mime, msgType);
  }

  Future<void> _uploadAndSend(
    List<int> bytes,
    String filename,
    String mime,
    String msgType, {
    int? durationMs,
  }) async {
    setState(() => _uploading = true);
    final media = context.read<MediaRepository>();
    final rt = context.read<RealtimeClient>();
    try {
      final uploaded = await media.upload(
        Uint8List.fromList(bytes),
        filename,
        mime,
        durationMs: durationMs,
      );
      if (rt.connected) {
        rt.sendMedia(widget.convId, uploaded.id, msgType,
            "tmp-${DateTime.now().microsecondsSinceEpoch}");
      } else {
        final msg = await context.read<ChatRepository>().sendMedia(widget.convId, uploaded.id, msgType);
        if (mounted) setState(() => _messages = [..._messages, msg]);
      }
      _scrollToBottom();
    } on ApiException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError(tr(context, 'send_failed'));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _startVoiceRecord() async {
    if (_uploading || _recording) return;
    if (!_voiceRecorder.isSupported) {
      _showError(tr(context, 'micro_unavailable_platform'));
      return;
    }
    final ok = await _voiceRecorder.start();
    if (!ok) {
      _showError(tr(context, 'micro_unavailable'));
      return;
    }
    setState(() {
      _recording = true;
      _recordStarted = DateTime.now();
    });
  }

  Future<void> _stopVoiceRecord({bool cancel = false}) async {
    if (!_recording) return;
    setState(() => _recording = false);
    if (cancel) {
      _voiceRecorder.cancel();
      return;
    }
    final result = await _voiceRecorder.stop();
    if (result == null || result.bytes.isEmpty) return;
    final ext = kIsWeb ? "webm" : "m4a";
    final mime = kIsWeb ? "audio/webm" : "audio/mp4";
    await _uploadAndSend(
      result.bytes,
      "vocal-${DateTime.now().millisecondsSinceEpoch}.$ext",
      mime,
      "AUDIO",
      durationMs: result.durationMs,
    );
  }

  String _ext(String name) {
    final i = name.lastIndexOf(".");
    return i >= 0 ? name.substring(i + 1).toLowerCase() : "";
  }

  String _mimeFromName(String name) {
    switch (_ext(name)) {
      case "png":
        return "image/png";
      case "gif":
        return "image/gif";
      case "webp":
        return "image/webp";
      case "jpg":
      case "jpeg":
        return "image/jpeg";
      case "pdf":
        return "application/pdf";
      case "doc":
        return "application/msword";
      case "docx":
        return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
      case "xls":
        return "application/vnd.ms-excel";
      case "xlsx":
        return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
      case "ppt":
      case "pptx":
        return "application/vnd.ms-powerpoint";
      case "txt":
        return "text/plain";
      case "csv":
        return "text/csv";
      case "zip":
        return "application/zip";
      case "rar":
        return "application/vnd.rar";
      case "7z":
        return "application/x-7z-compressed";
      case "mp3":
        return "audio/mpeg";
      case "wav":
        return "audio/wav";
      case "mp4":
        return "video/mp4";
      case "mov":
        return "video/quicktime";
      default:
        return "application/octet-stream";
    }
  }

  String _mediaUrl(MessageMedia m) => "$_baseUrl${m.url}?token=${_token ?? ''}";

  String _downloadUrl(MessageMedia m) =>
      "$_baseUrl${m.url}?download=1&token=${_token ?? ''}";

  Future<void> _download(MessageMedia m) async {
    final name = m.filename ?? "fichier-${m.id}";
    await downloadUrl(_downloadUrl(m), name);
  }

  // Icône + couleur selon l'extension/le type du fichier.
  _FileVisual _fileVisual(MessageMedia m) {
    final ext = _ext(m.filename ?? "");
    final mime = m.mimeType;
    if (mime == "application/pdf" || ext == "pdf") {
      return const _FileVisual(Icons.picture_as_pdf, Color(0xFFD32F2F));
    }
    if (ext == "doc" || ext == "docx") {
      return const _FileVisual(Icons.description, Color(0xFF1565C0));
    }
    if (ext == "xls" || ext == "xlsx" || ext == "csv") {
      return const _FileVisual(Icons.table_chart, Color(0xFF2E7D32));
    }
    if (ext == "ppt" || ext == "pptx") {
      return const _FileVisual(Icons.slideshow, Color(0xFFE64A19));
    }
    if (ext == "zip" || ext == "rar" || ext == "7z") {
      return const _FileVisual(Icons.folder_zip, Color(0xFF6D4C41));
    }
    if (mime.startsWith("audio/")) {
      return const _FileVisual(Icons.audiotrack, Color(0xFF7B1FA2));
    }
    if (mime.startsWith("video/")) {
      return const _FileVisual(Icons.movie, Color(0xFF00838F));
    }
    if (mime.startsWith("text/")) {
      return const _FileVisual(Icons.article, Color(0xFF455A64));
    }
    return const _FileVisual(Icons.insert_drive_file, AppColors.chocolate);
  }

  String _humanSize(int? bytes) {
    if (bytes == null || bytes <= 0) return "";
    const units = ["o", "Ko", "Mo", "Go"];
    var size = bytes.toDouble();
    var u = 0;
    while (size >= 1024 && u < units.length - 1) {
      size /= 1024;
      u++;
    }
    final v = u == 0 ? size.toStringAsFixed(0) : size.toStringAsFixed(1);
    return "$v ${units[u]}";
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String m) => showAppSnackBar(m);

  Future<void> _startCall(String type) async {
    final cc = context.read<CallController>();
    try {
      await cc.startOutgoing(widget.convId, type, widget.title);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const ActiveCallScreen(),
        ),
      );
    } on StateError catch (_) {
      _showError("Tu es déjà en appel");
    } catch (_) {
      _showError(tr(context, 'error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AuthController>().user?.id;
    return Scaffold(
      appBar: backAppBar(
        context,
        widget.title,
        actions: [
          IconButton(
            tooltip: widget.isGroup ? "Appel groupe audio" : "Appel audio",
            icon: const Icon(Icons.call),
            onPressed: () => _startCall("AUDIO"),
          ),
          IconButton(
            tooltip: widget.isGroup ? "Appel groupe vidéo" : "Appel vidéo",
            icon: const Icon(Icons.videocam),
            onPressed: () => _startCall("VIDEO"),
          ),
        ],
      ),
      body: MotifBackground(
        overlayOpacity: 0.85,
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.terracotta))
                  : _messages.isEmpty
                      ? Center(child: Text(tr(context, 'no_messages')))
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(12),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) => _bubble(_messages[i], _messages[i].senderId == myId),
                        ),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _bubble(Message m, bool mine) {
    final isImage = m.type == "IMAGE" && m.media.isNotEmpty;
    final isFile = m.type == "FILE" && m.media.isNotEmpty;
    final isAudio = m.type == "AUDIO" && m.media.isNotEmpty;
    final senderLabel = widget.isGroup && !mine
        ? (widget.memberNames[m.senderId] ?? "Membre")
        : null;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (senderLabel != null)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 2),
              child: Text(
                senderLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.forest,
                ),
              ),
            ),
          Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        // Image : marge interne fine pour une vignette quasi pleine bulle (style WhatsApp).
        padding: isImage
            ? const EdgeInsets.all(3)
            : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: mine ? AppColors.terracotta : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: mine ? null : Border.all(color: AppColors.sand),
        ),
        child: isImage
            ? _imageBubble(m, mine)
            : isFile
                ? _fileBubble(m, mine)
                : isAudio
                    ? _audioBubble(m, mine)
                    : _textBubble(m, mine),
          ),
        ],
      ),
    );
  }

  // Vignette image avec horodatage + accusés et bouton de téléchargement.
  Widget _imageBubble(Message m, bool mine) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => _download(m.media.first),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: AuthNetworkImage(
                url: "$_baseUrl${m.media.first.url}",
                token: _token,
                width: 274,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
          Positioned(
            right: 6,
            top: 6,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => _download(m.media.first),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.download, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _time(m.createdAt) + (mine ? (m.status == "READ" ? " ✓✓" : " ✓") : ""),
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Pièce jointe non-image : icône d'extension + nom + taille + téléchargement.
  Widget _fileBubble(Message m, bool mine) {
    final media = m.media.first;
    final _FileVisual visual = _fileVisual(media);
    final name = media.filename ?? tr(context, 'file');
    final ext = _ext(name);
    final size = _humanSize(media.sizeBytes);
    final onText = mine ? Colors.white : AppColors.ink;
    final onSub = mine ? Colors.white70 : Colors.black45;
    return InkWell(
      onTap: () => _download(media),
      borderRadius: BorderRadius.circular(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: visual.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(visual.icon, color: visual.color, size: 26),
                    if (ext.isNotEmpty)
                      Positioned(
                        bottom: 2,
                        child: Text(
                          ext.toUpperCase(),
                          style: TextStyle(
                            fontSize: 7,
                            fontWeight: FontWeight.bold,
                            color: visual.color,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: onText, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (size.isNotEmpty)
                          Text(size, style: TextStyle(fontSize: 11, color: onSub)),
                        if (size.isNotEmpty) const SizedBox(width: 8),
                        Icon(Icons.download, size: 14, color: onSub),
                        const SizedBox(width: 2),
                        Text(tr(context, 'download'),
                            style: TextStyle(fontSize: 11, color: onSub)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _time(m.createdAt) + (mine ? (m.status == "READ" ? " ✓✓" : " ✓") : ""),
            style: TextStyle(fontSize: 10, color: onSub),
          ),
        ],
      ),
    );
  }

  // Message vocal : bouton lecture + barre de progression stylisée (style WhatsApp).
  Widget _audioBubble(Message m, bool mine) {
    final media = m.media.first;
    final secs = media.durationMs != null ? (media.durationMs! / 1000).round() : null;
    final onSub = mine ? Colors.white70 : Colors.black45;
    final accent = mine ? Colors.white : AppColors.terracotta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => InlineAudioPlayer.play(_mediaUrl(media)),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: accent.withOpacity(0.15),
                child: Icon(Icons.play_arrow, color: accent, size: 22),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: 1,
                        minHeight: 4,
                        backgroundColor: onSub.withOpacity(0.3),
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    secs != null ? "${secs}s" : tr(context, 'voice_message'),
                    style: TextStyle(fontSize: 12, color: onSub),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              Icon(Icons.mic, size: 16, color: onSub),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _time(m.createdAt) + (mine ? (m.status == "READ" ? " ✓✓" : " ✓") : ""),
          style: TextStyle(fontSize: 10, color: onSub),
        ),
      ],
    );
  }

  Future<void> _translateMessage(Message m) async {
    final text = (m.content ?? '').trim();
    if (text.isEmpty) return;
    final locale = context.read<LocaleController>().languageCode;
    // Si déjà traduit, on toggle (masquer)
    if (_translations.containsKey(m.id)) {
      setState(() => _translations.remove(m.id));
      return;
    }
    if (_translating.contains(m.id)) return;
    setState(() => _translating.add(m.id));
    try {
      // Détection simple : si l'utilisateur est en FR, on traduit vers FR, sinon EN
      // source = auto
      final translated = await _translateService.translate(
        text: text,
        target: locale,
        source: 'auto',
      );
      if (!mounted) return;
      setState(() => _translations[m.id] = translated);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'translation_failed'))),
        );
      }
    } finally {
      if (mounted) setState(() => _translating.remove(m.id));
    }
  }

  Widget _textBubble(Message m, bool mine) {
    final translated = _translations[m.id];
    final isTranslating = _translating.contains(m.id);
    final onTextColor = mine ? Colors.white : AppColors.ink;
    final onSubColor = mine ? Colors.white70 : Colors.black45;

    return GestureDetector(
      onTap: m.type == 'TEXT' && (m.content ?? '').isNotEmpty
          ? () => _translateMessage(m)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            m.content ?? "[${m.type}]",
            style: TextStyle(color: onTextColor),
          ),
          if (translated != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: mine ? Colors.white.withOpacity(0.15) : AppColors.sand.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.translate, size: 12, color: onSubColor),
                      const SizedBox(width: 4),
                      Text(
                        tr(context, 'translated'),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: onSubColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    translated,
                    style: TextStyle(fontSize: 13, color: onTextColor, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
          if (isTranslating) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: onSubColor),
                ),
                const SizedBox(width: 6),
                Text(tr(context, 'translating'), style: TextStyle(fontSize: 10, color: onSubColor)),
              ],
            ),
          ],
          if (!isTranslating && translated == null && m.type == 'TEXT')
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                tr(context, 'translate'),
                style: TextStyle(fontSize: 10, color: onSubColor.withOpacity(0.8), fontStyle: FontStyle.italic),
              ),
            ),
          const SizedBox(height: 2),
          Text(
            _time(m.createdAt) + (mine ? (m.status == "READ" ? " ✓✓" : " ✓") : ""),
            style: TextStyle(
              fontSize: 10,
              color: onSubColor,
            ),
          ),
        ],
      ),
    );
  }

  String _time(DateTime d) {
    final l = d.toLocal();
    return "${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}";
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_recording)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.red.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.fiber_manual_record, color: Colors.red.shade700, size: 14),
                  const SizedBox(width: 8),
                  Text(tr(context, 'recording_hold'),
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            color: AppColors.cream,
            child: Row(
              children: [
                IconButton(
                  tooltip: tr(context, 'attach_file'),
                  icon: _uploading
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.attach_file, color: AppColors.chocolate),
                  onPressed: _uploading || _recording ? null : _pickAndSendFile,
                ),
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: tr(context, 'write_message'),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onLongPressStart: (_) => _startVoiceRecord(),
                  onLongPressEnd: (_) => _stopVoiceRecord(),
                  onLongPressCancel: () => _stopVoiceRecord(cancel: true),
                  child: CircleAvatar(
                    backgroundColor: _recording ? Colors.red : AppColors.forest,
                    child: Icon(
                      _recording ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.terracotta,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sending || _recording ? null : _send,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FileVisual {
  final IconData icon;
  final Color color;
  const _FileVisual(this.icon, this.color);
}
