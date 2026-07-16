import '../../core/authed_api.dart';
import '../../models/status.dart';

class StatusRepository {
  StatusRepository(this._api);

  final AuthedApi _api;

  /// Fil d'actualité des statuts (contacts + soi).
  /// ✅ NOUVEAU : GET /api/statuses (paginé)
  Future<StatusFeed> feed({int limit = 20, String? cursor}) async {
    String path = '/api/statuses?limit=$limit';
    if (cursor != null) path += '&cursor=$cursor';
    final data = await _api.get(path);
    return StatusFeed.fromJson(data);
  }

  /// Statuts d'un utilisateur spécifique.
  Future<List<Status>> getUserStatuses(String targetUserId) async {
    final data = await _api.get('/api/statuses/user/$targetUserId');
    return (data as List)
        .map((s) => Status.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Publie un statut texte avec couleur de fond (hex #RRGGBB).
  /// ✅ NOUVEAU : POST /api/statuses avec type: 'text'
  Future<Status> createText(String text, String bgColor) async {
    final data = await _api.post('/api/statuses', {
      'type': 'text',
      'content': text,
      'backgroundColor': bgColor,
    });
    return Status.fromJson(data);
  }

  /// Publie un statut média (image ou vidéo) via l'ID d'un média déjà uploadé.
  /// ✅ NOUVEAU : POST /api/statuses avec type: 'image'|'video' et mediaId
  Future<Status> createMedia(String mediaId, String type) async {
    final data = await _api.post('/api/statuses', {
      'type': type, // 'image' ou 'video'
      'mediaId': mediaId,
    });
    return Status.fromJson(data);
  }

  /// Marque un statut comme vu.
  Future<void> markViewed(String statusId) async {
    await _api.post('/api/statuses/$statusId/view', {});
  }

  /// Supprime son propre statut.
  Future<void> delete(String statusId) async {
    await _api.delete('/api/statuses/$statusId');
  }

  /// Qui a vu son statut (auteur seulement).
  Future<List<Map<String, dynamic>>> getViews(String statusId) async {
    final data = await _api.get('/api/statuses/$statusId/views');
    return (data as List).cast<Map<String, dynamic>>();
  }
}