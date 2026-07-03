import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Télécharge un média depuis une URL authentifiée, l'enregistre dans le dossier
/// « SewaChat » de l'appareil (organisé par type), puis l'ouvre.
///
/// Sur Android : utilise le stockage externe de l'app (getExternalStorageDirectory)
/// car getDownloadsDirectory() retourne null sur Android.
Future<String?> downloadUrl(String url, String filename) async {
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

/// Vérifie si un fichier est déjà présent dans le cache SewaChat.
Future<String?> getCachedFile(String filename) async {
  try {
    final baseDir = await _getBaseDir();
    final ext = _ext(filename).toLowerCase();
    final subfolder = _subfolderFor(ext);
    final path = '${baseDir.path}/SewaChat/$subfolder/$filename';
    if (await File(path).exists()) return path;
    return null;
  } catch (_) {
    return null;
  }
}

// --- Helpers ---

String _ext(String filename) {
  final i = filename.lastIndexOf('.');
  return i >= 0 ? filename.substring(i + 1) : '';
}

String _subfolderFor(String ext) {
  const images = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
  const videos = {'mp4', 'mov', 'avi', 'mkv', 'webm'};
  const audios = {'mp3', 'wav', 'aac', 'ogg', 'm4a'};
  if (images.contains(ext)) return 'Images';
  if (videos.contains(ext)) return 'Videos';
  if (audios.contains(ext)) return 'Audio';
  return 'Documents';
}

/// Répertoire de base selon la plateforme.
/// Android : getExternalStorageDirectory() (stockage externe de l'app, toujours accessible).
/// iOS/Desktop : getDownloadsDirectory() ou getApplicationDocumentsDirectory() en repli.
Future<Directory> _getBaseDir() async {
  if (Platform.isAndroid) {
    // getDownloadsDirectory() retourne null sur Android.
    // getExternalStorageDirectory() → /storage/emulated/0/Android/data/<pkg>/files
    return getExternalStorageDirectory() ?? getApplicationDocumentsDirectory();
  }
  final downloads = await getDownloadsDirectory();
  if (downloads != null) return downloads;
  return getApplicationDocumentsDirectory();
}

Future<String> _uniquePath(String dirPath, String filename) async {
  final ext = _ext(filename);
  final nameWithoutExt = ext.isNotEmpty
      ? filename.substring(0, filename.length - ext.length - 1)
      : filename;
  var candidate = '$dirPath/$filename';
  var counter = 1;
  while (await File(candidate).exists()) {
    final suffix = ext.isNotEmpty ? '$nameWithoutExt($counter).$ext' : '$nameWithoutExt($counter)';
    candidate = '$dirPath/$suffix';
    counter++;
  }
  return candidate;
}

Future<void> _openFile(String path) async {
  final uri = Uri.file(path);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
}
