import '../../core/authed_api.dart';

/// Champs de profil renvoyés après mise à jour.
class ProfileUpdate {
  final String? pseudo;
  final String? avatarUrl;
  final String? statusMsg;
  final String? nom;
  final int? idPays;

  ProfileUpdate({this.pseudo, this.avatarUrl, this.statusMsg, this.nom, this.idPays});
}

class AccountRepository {
  AccountRepository(this._api);

  final AuthedApi _api;

  /// Met à jour le profil de l'utilisateur connecté.
  /// ✅ NOUVEAU : PUT /api/users/me (au lieu de PATCH /api/account/profile)
  Future<ProfileUpdate> updateProfile({
    String? pseudo,
    String? statusMsg,
    String? avatarUrl,
    String? nom,
    int? idPays,
  }) async {
    final body = <String, dynamic>{};
    if (pseudo != null) body['pseudo'] = pseudo;
    if (statusMsg != null) body['statusMsg'] = statusMsg;
    if (avatarUrl != null) body['avatarUrl'] = avatarUrl;
    if (nom != null) body['nom'] = nom;
    if (idPays != null) body['idPays'] = idPays;

    final data = await _api.put('/api/users/me', body);

    return ProfileUpdate(
      pseudo: data['pseudo'] as String?,
      avatarUrl: data['avatarUrl'] as String?,
      statusMsg: data['statusMsg'] as String?,
      nom: data['nom'] as String?,
      idPays: data['idPays'] as int?,
    );
  }

  /// Récupère le profil complet de l'utilisateur connecté.
  /// ✅ NOUVEAU : GET /api/users/me
  Future<Map<String, dynamic>> getProfile() async {
    return _api.get('/api/users/me');
  }

  /// Récupère un utilisateur par son numéro public.
  Future<Map<String, dynamic>> getByPublicNumber(String publicNumber) async {
    return _api.get('/api/users/public/$publicNumber');
  }

  /// Recherche des utilisateurs.
  Future<Map<String, dynamic>> searchUsers({
    String? query,
    int limit = 20,
    String? cursor,
  }) async {
    String path = '/api/users/search?limit=$limit';
    if (query != null && query.isNotEmpty) {
      path += '&q=${Uri.encodeQueryComponent(query)}';
    }
    if (cursor != null) {
      path += '&cursor=$cursor';
    }
    return _api.get(path);
  }
}