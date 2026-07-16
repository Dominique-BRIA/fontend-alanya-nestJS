import 'dart:typed_data';
import '../../core/authed_api.dart';

/// Résultat d'un upload média.
class UploadedMedia {
  final String id;
  final String url; // URL de téléchargement (presigned ou endpoint local)
  final String mimeType;
  final int size;
  final String filename;

  UploadedMedia({
    required this.id,
    required this.url,
    required this.mimeType,
    required this.size,
    required this.filename,
  });
}

/// Informations pour l'upload presigné.
class PresignedUploadInfo {
  final String mediaId;
  final String uploadUrl;
  final String method; // PUT ou POST
  final Map<String, String>? headers;
  final String key;
  final String provider; // 'local' ou 'b2'

  PresignedUploadInfo({
    required this.mediaId,
    required this.uploadUrl,
    required this.method,
    this.headers,
    required this.key,
    required this.provider,
  });
}

class MediaRepository {
  MediaRepository(this._api);

  final AuthedApi _api;

  /// Étape 1 : Obtenir une URL presignée pour l'upload.
  /// ✅ NOUVEAU : Flow en 3 étapes (presign → upload direct → confirm)
  Future<PresignedUploadInfo> getPresignedUploadUrl({
    required String filename,
    required String mimeType,
    required int size,
  }) async {
    final data = await _api.post('/api/media/presign-upload', {
      'filename': filename,
      'mimeType': mimeType,
      'size': size,
    });

    return PresignedUploadInfo(
      mediaId: data['mediaId'] as String,
      uploadUrl: data['uploadUrl'] as String,
      method: data['method'] as String,
      headers: (data['headers'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)),
      key: data['key'] as String,
      provider: data['provider'] as String,
    );
  }

  /// Étape 2 : Upload direct vers l'URL presignée (S3/B2/local).
  /// Cette méthode n'utilise PAS l'API backend, elle upload directement vers le storage.
  Future<void> uploadDirect(PresignedUploadInfo info, Uint8List bytes) async {
    // Import http ici pour éviter la dépendance circulaire
    import 'package:http/http.dart' as http;
    
    final request = http.Request(info.method, Uri.parse(info.uploadUrl));
    request.headers.addAll(info.headers ?? {});
    request.bodyBytes = bytes;
    
    final response = await request.send();
    if (response.statusCode >= 400) {
      throw Exception('Upload failed: ${response.statusCode}');
    }
  }

  /// Étape 3 : Confirmer l'upload auprès du backend.
  Future<UploadedMedia> confirmUpload({
    required String mediaId,
    required String filename,
    required String mimeType,
    required int size,
    String? conversationId,
  }) async {
    final data = await _api.post('/api/media/confirm-upload', {
      'mediaId': mediaId,
      'filename': filename,
      'mimeType': mimeType,
      'size': size,
      if (conversationId != null) 'conversationId': conversationId,
    });

    return UploadedMedia(
      id: data['id'] as String,
      url: data['url'] as String? ?? '/api/media/${data['id']}/download',
      mimeType: data['mimeType'] as String,
      size: (data['size'] as num).toInt(),
      filename: data['filename'] as String,
    );
  }

  /// Upload complet (helper qui fait les 3 étapes).
  Future<UploadedMedia> upload({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
    int? durationMs,
    String? conversationId,
  }) async {
    final info = await getPresignedUploadUrl(
      filename: filename,
      mimeType: mimeType,
      size: bytes.length,
    );
    
    await uploadDirect(info, bytes);
    
    return confirmUpload(
      mediaId: info.mediaId,
      filename: filename,
      mimeType: mimeType,
      size: bytes.length,
      conversationId: conversationId,
    );
  }

  /// Récupère les infos d'un média.
  Future<Map<String, dynamic>> getMedia(String mediaId) async {
    return _api.get('/api/media/$mediaId');
  }

  /// Obtient une URL de téléchargement (presigned pour B2, endpoint local sinon).
  Future<String> getDownloadUrl(String mediaId) async {
    final data = await _api.get('/api/media/$mediaId/download');
    return data['downloadUrl'] as String;
  }

  /// Supprime un média.
  Future<void> delete(String mediaId) async {
    await _api.delete('/api/media/$mediaId');
  }

  /// Médias d'une conversation.
  Future<List<Map<String, dynamic>>> getConversationMedia(String conversationId, {int limit = 50}) async {
    final data = await _api.get('/api/media/conversation/$conversationId?limit=$limit');
    return (data as List).cast<Map<String, dynamic>>();
  }
}