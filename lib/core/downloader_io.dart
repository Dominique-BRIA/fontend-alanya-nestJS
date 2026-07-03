import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Télécharge un média depuis une URL authentifiée, l'enregistre dans le dossier
/// « SewaChat » de l'appareil (organisé par type), puis l'ouvre.
///
/// [url] doit inclure le token d'authentification (?token=...).
/// [filename] sert à déterminer le type et le nom du fichier.
/// Retourne le chemin local du fichier sauvegardé (null en cas d'échec).
Future<String?> downloadUrl(String url, String filename) async {
  try {
    // 1) Télécharge les octets depuis le serveur (l'URL contient déjà le token).
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;
    final bytes = response.bodyBytes;

    // 2) Détermine le sous-dossier selon le type de fichier.
    final ext = _ext(filename).toLowerCase();
    final subfolder = _subfolderFor(ext);

    // 3) Crée le dossier SewaChat/{sous-dossier}.
    final baseDir = await _getBaseDir();
    final dir = Directory('${baseDir.path}/SewaChat/$subfolder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 4) Évite d'écraser un fichier existant : ajoute un suffixe si besoin.
    final savedPath = await _uniquePath(dir.path, filename);
    final file = File(savedPath);
    await file.writeAsBytes(bytes);

    // 5) Ouvre le fichier avec l'application système appropriée.
    await _openFile(savedPath);

    return savedPath;
  } catch (_) {
    return null;
  }
}

/// Télécharge uniquement (sans ouvrir). Retourne le chemin local ou null.
Future<String?> downloadOnly(String url, String filename) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return null;
    final bytes = response.bodyBytes;

    final ext = _ext(filename).toLowerCase();
    final subfolder = _subfolderFor(ext);

    final baseDir = await _getBaseDir();
    final dir = Directory('${baseDir.path}/SewaChat/$subfolder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final savedPath = await _uniquePath(dir.path, filename);
    await File(savedPath).writeAsBytes(bytes);
    return savedPath;
  } catch (_) {
    return null;
  }
}

/// Ouvre un fichier local avec l'application système appropriée.
Future<void> openLocalFile(String path) async => _openFile(path);

// --- Helpers ---

String _ext(String filename) {
  final i = filename.lastIndexOf('.');
  return i >= 0 ? filename.substring(i + 1) : '';
}

/// Détermine le sous-dossier selon l'extension du fichier.
String _subfolderFor(String ext) {
  const images = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
  const videos = {'mp4', 'mov', 'avi', 'mkv', 'webm'};
  const audios = {'mp3', 'wav', 'aac', 'ogg', 'm4a', 'webm'};
  if (images.contains(ext)) return 'Images';
  if (videos.contains(ext)) return 'Videos';
  if (audios.contains(ext)) return 'Audio';
  return 'Documents';
}

/// Répertoire de base : Downloads sur Android, Documents sur desktop.
Future<Directory> _getBaseDir() async {
  if (Platform.isAndroid || Platform.isIOS) {
    // /storage/emulated/0/Download (Android) ou Documents (iOS)
    return getDownloadsDirectory() ?? getApplicationDocumentsDirectory();
  }
  return getDownloadsDirectory() ?? getApplicationDocumentsDirectory();
}

/// Génère un chemin unique (ajoute (1), (2)… si le fichier existe déjà).
Future<String> _uniquePath(String dirPath, String filename) async {
  final base = filename;
  final ext = _ext(base);
  final nameWithoutExt = ext.isNotEmpty ? base.substring(0, base.length - ext.length - 1) : base;
  var candidate = '$dirPath/$base';
  var counter = 1;
  while (await File(candidate).exists()) {
    final suffix = ext.isNotEmpty ? '$nameWithoutExt($counter).$ext' : '$nameWithoutExt($counter)';
    candidate = '$dirPath/$suffix';
    counter++;
  }
  return candidate;
}

/// Ouvre un fichier avec l'application par défaut du système.
Future<void> _openFile(String path) async {
  final uri = Uri.file(path);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    // Silencieux : le fichier est sauvegardé même si l'ouverture échoue.
  }
}
