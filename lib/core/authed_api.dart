import 'dart:typed_data';

import 'api_client.dart';
import 'token_storage.dart';

/// Enveloppe l'ApiClient pour injecter automatiquement l'access token et
/// rafraîchir la session une fois en cas de 401.
class AuthedApi {
  AuthedApi(this._api, this._storage);

  final ApiClient _api;
  final TokenStorage _storage;

  Future<Map<String, dynamic>> get(String path) =>
      _withAuth((token) => _api.get(path, bearer: token));

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) =>
      _withAuth((token) => _api.post(path, body, bearer: token));

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) =>
      _withAuth((token) => _api.patch(path, body, bearer: token));

  Future<Map<String, dynamic>> delete(String path) =>
      _withAuth((token) => _api.delete(path, bearer: token));

  Future<Map<String, dynamic>> uploadBytes(
    String path,
    Uint8List bytes,
    String filename,
    String mimeType, {
    Map<String, String>? fields,
  }) =>
      _withAuth((token) =>
          _api.uploadBytes(path, bytes, filename, mimeType, bearer: token, fields: fields));

  Future<Map<String, dynamic>> _withAuth(
    Future<Map<String, dynamic>> Function(String token) call,
  ) async {
    final token = await _storage.accessToken;
    if (token == null) throw ApiException(401, "Session expirée");
    try {
      return await call(token);
    } on ApiException catch (e) {
      if (e.statusCode != 401) rethrow;
      // Tente un refresh puis réessaie une fois.
      final refreshed = await _refresh();
      if (refreshed == null) rethrow;
      return call(refreshed);
    }
  }

  Future<String?> _refresh() async {
    final refresh = await _storage.refreshToken;
    if (refresh == null) return null;
    try {
      final data = await _api.post("/api/auth/refresh", {"refreshToken": refresh});
      final access = data["accessToken"] as String;
      final newRefresh = data["refreshToken"] as String;
      await _storage.saveTokens(access: access, refresh: newRefresh);
      return access;
    } catch (_) {
      await _storage.clear();
      return null;
    }
  }
}
