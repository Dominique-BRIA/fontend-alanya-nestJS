import 'dart:convert';
import '../../core/api_client.dart';
import '../../models/auth_user.dart';

/// Résultat de la vérification OTP : token d'étape + numéro public attribué.
class VerifyResult {
  final String setupToken;
  final String publicNumber;
  final bool needsSetup;

  VerifyResult(this.setupToken, this.publicNumber, this.needsSetup);
}

/// Résultat d'une authentification réussie (setup ou login).
class AuthSession {
  final AuthUser user;
  final String accessToken;
  final String refreshToken;

  AuthSession(this.user, this.accessToken, this.refreshToken);
}

/// Tokens rafraîchis (sans user – il faut rappeler /api/me après).
class RefreshSession {
  final String accessToken;
  final String refreshToken;

  RefreshSession(this.accessToken, this.refreshToken);
}

/// Appelle les endpoints d'authentification du backend NestJS.
class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  /// Étape 1 : inscription avec email, password, pays optionnel.
  /// Le backend NestJS attend : { email, password, idPays?, nom? }
  Future<void> register({
    required String email,
    required String password,
    int? idPays,
    String? nom,
  }) async {
    await _api.post('/api/auth/register', {
      'email': email,
      'password': password,
      if (idPays != null) 'idPays': idPays,
      if (nom != null && nom.isNotEmpty) 'nom': nom,
    });
  }

  /// Étape 2 : vérifie le code OTP à 6 chiffres.
  Future<VerifyResult> verify(String email, String code) async {
    final data = await _api.post('/api/auth/verify', {'email': email, 'code': code});

    return VerifyResult(
      data['setupToken'] as String,
      data['publicNumber'] as String,
      (data['needsSetup'] as bool?) ?? true,
    );
  }

  /// Étape 3 : choix du pseudo + mot de passe (avec le setupToken).
  Future<AuthSession> setup({
    required String setupToken,
    required String pseudo,
    required String password,
  }) async {
    final data = await _api.post(
      '/api/auth/setup',
      {'pseudo': pseudo, 'password': password},
      bearer: setupToken,
    );

    return _session(data);
  }

  /// Connexion par email + mot de passe.
  /// ✅ NOUVEAU : Le backend NestJS n'accepte que l'email (pas le numéro public)
  Future<AuthSession> login({required String email, required String password}) async {
    final data = await _api.post('/api/auth/login', {'email': email, 'password': password});
    return _session(data);
  }

  /// Mot de passe oublié : déclenche l'envoi du code OTP.
  Future<void> forgotPassword(String email) async {
    await _api.post('/api/auth/forgot-password', {'email': email});
  }

  /// Réinitialisation du mot de passe avec le code OTP.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _api.post('/api/auth/reset-password', {
      'email': email,
      'code': code,
      'password': newPassword,
    });
  }

  /// Récupère le profil de l'utilisateur connecté.
  Future<AuthUser> me(String accessToken) async {
    final data = await _api.get('/api/users/me', bearer: accessToken);
    return AuthUser.fromJson(data);
  }

  /// Rafraîchit un access token expiré à partir du refresh token.
  Future<RefreshSession> refresh(String refreshToken) async {
    final data = await _api.post('/api/auth/refresh', {'refreshToken': refreshToken});
    return RefreshSession(
      data['accessToken'] as String,
      data['refreshToken'] as String,
    );
  }

  Future<void> logout(String refreshToken) async {
    await _api.post('/api/auth/logout', {'refreshToken': refreshToken});
  }

  /// Renvoyer le code de vérification email.
  Future<void> resendVerification(String email) async {
    await _api.post('/api/auth/resend-verification', {'email': email});
  }

  AuthSession _session(Map<String, dynamic> data) => AuthSession(
    AuthUser.fromJson(data['user'] as Map<String, dynamic>),
    data['accessToken'] as String,
    data['refreshToken'] as String,
  );
}