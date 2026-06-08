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

/// Appelle les endpoints d'authentification du backend.
class AuthRepository {
  AuthRepository(this._api);
  final ApiClient _api;

  /// Étape 1 : demande l'envoi du code OTP par email.
  Future<void> register(String email) async {
    await _api.post("/api/auth/register", {"email": email});
  }

  /// Étape 2 : vérifie le code OTP à 6 chiffres.
  Future<VerifyResult> verify(String email, String code) async {
    final data = await _api.post("/api/auth/verify", {"email": email, "code": code});
    return VerifyResult(
      data["setupToken"] as String,
      data["publicNumber"] as String,
      (data["needsSetup"] as bool?) ?? true,
    );
  }

  /// Étape 3 : choix du pseudo + mot de passe (avec le setupToken).
  Future<AuthSession> setup({
    required String setupToken,
    required String pseudo,
    required String password,
  }) async {
    final data = await _api.post(
      "/api/auth/setup",
      {"pseudo": pseudo, "password": password},
      bearer: setupToken,
    );
    return _session(data);
  }

  /// Connexion par email OU numéro public à 6 chiffres.
  Future<AuthSession> login({required String identifier, required String password}) async {
    final data =
        await _api.post("/api/auth/login", {"identifier": identifier, "password": password});
    return _session(data);
  }

  Future<AuthUser> me(String accessToken) async {
    final data = await _api.get("/api/me", bearer: accessToken);
    return AuthUser.fromJson(data);
  }

  Future<void> logout(String refreshToken) async {
    await _api.post("/api/auth/logout", {"refreshToken": refreshToken});
  }

  AuthSession _session(Map<String, dynamic> data) => AuthSession(
        AuthUser.fromJson(data["user"] as Map<String, dynamic>),
        data["accessToken"] as String,
        data["refreshToken"] as String,
      );
}
