import 'dart:io';

import 'package:flutter/foundation.dart';
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
    debugPrint('[SewaChat] Téléchargement: $filename depuis $url');

    // 1) Télécharge les octets depuis le serveur.
    final response = await http.get(Uri.parse(url));
    debugPrint('[SewaChat] Statut HTTP: ${response.statusCode}');

    if (response.statusCode != 200) {
      debugPrint('[SewaChat] Échec téléchargement: HTTP ${response.statusCode}');
      return null;
    }
    final bytes = response.bodyBytes;
    debugPrint('[SewaChat] Téléchargé: ${bytes.length} octets');

    // 2) Détermine le sous-dossier selon le type de fichier.
    final ext = _ext(filename).toLowerCase();
    final subfolder = _subfolderFor(ext);

    // 3) Crée le dossier SewaChat/{sous-dossier}.
    final baseDir = await _getBaseDir();
    final dir = Directory('${baseDir.path}/SewaChat/$subfolder');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
      debugPrint('[SewaChat] Dossier créé: ${dir.path}');
    }

    // 4) Évite d'écraser un fichier existant.
    final savedPath = await _uniquePath(dir.path, filename);
    final file = File(savedPath);
    await file.writeAsBytes(bytes);
    debugPrint('[SewaChat] Fichier sauvegardé: $savedPath');

    // 5) Tente d'ouvrir le fichier.
    await _openFile(savedPath);

    return savedPath;
  } catch (e) {
    debugPrint('[SewaChat] Erreur téléchargement: $e');
    return null;
  }
}

/// Télécharge uniquement (sans ouvrir). Retourne le chemin local ou null.
Future<String?> downloadOnly(String url, String filename) async {
  try {
    debugPrint('[SewaChat] Téléchargement (sans ouverture): $filename');

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      debugPrint('[SewaChat] Échec: HTTP ${response.statusCode}');
      return null;
    }
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
    debugPrint('[SewaChat] Sauvegardé: $savedPath');
    return savedPath;
  } catch (e) {
    debugPrint('[SewaChat] Erreur: $e');
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
Future<Directory> _getBaseDir() async {
  if (Platform.isAndroid) {
    // getExternalStorageDirectory() → /storage/emulated/0/Android/data/<pkg>/files
    final external = await getExternalStorageDirectory();
    if (external != null) return external;
    final docs = await getApplicationDocumentsDirectory();
    return docs;
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
    final suffix =
        ext.isNotEmpty ? '$nameWithoutExt($counter).$ext' : '$nameWithoutExt($counter)';
    candidate = '$dirPath/$suffix';
    counter++;
  }
  return candidate;
}

/// Ouvre un fichier avec l'application par défaut du système.
/// Sur Android, url_launcher utilise le FileProvider configuré dans AndroidManifest.
Future<void> _openFile(String path) async {
  try {
    final uri = Uri.file(path);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint('[SewaChat] Impossible d\'ouvrir: $path (canLaunchUrl=false)');
    }
  } catch (e) {
    debugPrint('[SewaChat] Erreur ouverture fichier: $e');
  }
}
