import 'package:flutter/foundation.dart';

import '../../core/token_storage.dart';
import '../../models/auth_user.dart';
import 'auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

/// État global d'authentification (exposé via Provider).
class AuthController extends ChangeNotifier {
  AuthController(this._repo, this._storage);

  final AuthRepository _repo;
  final TokenStorage _storage;

  AuthStatus status = AuthStatus.unknown;
  AuthUser? user;

  /// Au démarrage : tente de restaurer une session depuis les tokens stockés.
  Future<void> bootstrap() async {
    final access = await _storage.accessToken;
    if (access == null) {
      _set(AuthStatus.unauthenticated, null);
      return;
    }
    try {
      user = await _repo.me(access);
      _set(AuthStatus.authenticated, user);
    } catch (_) {
      await _storage.clear();
      _set(AuthStatus.unauthenticated, null);
    }
  }

  Future<void> completeSetup(AuthSession session) => _persist(session);

  Future<void> completeLogin(AuthSession session) => _persist(session);

  /// Met à jour localement le profil après une modification réussie côté API.
  void applyProfile({String? pseudo, String? avatarUrl, String? statusMsg}) {
    final current = user;
    if (current == null) return;
    user = current.copyWith(pseudo: pseudo, avatarUrl: avatarUrl, statusMsg: statusMsg);
    notifyListeners();
  }

  Future<void> logout() async {
    final refresh = await _storage.refreshToken;
    if (refresh != null) {
      try {
        await _repo.logout(refresh);
      } catch (_) {
        // on ignore : on déconnecte localement de toute façon
      }
    }
    await _storage.clear();
    _set(AuthStatus.unauthenticated, null);
  }

  Future<void> _persist(AuthSession session) async {
    await _storage.saveTokens(
      access: session.accessToken,
      refresh: session.refreshToken,
    );
    user = session.user;
    _set(AuthStatus.authenticated, session.user);
  }

  void _set(AuthStatus s, AuthUser? u) {
    status = s;
    user = u;
    notifyListeners();
  }
}
