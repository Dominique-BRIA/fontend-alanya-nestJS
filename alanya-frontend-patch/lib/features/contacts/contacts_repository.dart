import '../../core/authed_api.dart';
import '../../models/contact.dart';

class ContactsRepository {
  ContactsRepository(this._api);

  final AuthedApi _api;

  /// Recherche un utilisateur par query (pseudo, email, publicNumber, nom).
  /// ✅ NOUVEAU : Paramètre `q` au lieu de `number`
  Future<UserSearchResult> searchByQuery(String query) async {
    if (query.trim().isEmpty) throw ArgumentError('Query cannot be empty');
    final data = await _api.get('/api/users/search?q=${Uri.encodeQueryComponent(query)}');
    return UserSearchResult.fromJson(data);
  }

  /// Match plusieurs numéros - ❌ N'existe pas dans le backend NestJS.
  /// Solution : Appeler searchByQuery pour chaque numéro ou implémenter côté backend.
  Future<List<UserSearchResult>> matchNumbers(List<String> numbers) async {
    if (numbers.isEmpty) return [];
    
    final results = <UserSearchResult>[];
    for (final number in numbers) {
      try {
        final result = await searchByQuery(number);
        results.add(result);
      } on ApiException catch (e) {
        if (e.statusCode == 404) continue; // Pas trouvé, on ignore
        rethrow;
      }
    }
    return results;
  }

  /// Liste des contacts.
  /// ✅ NOUVEAU : Retourne directement la liste (pas enveloppé dans "contacts")
  Future<List<Contact>> list() async {
    final data = await _api.get('/api/contacts');
    final raw = data as List?; // data est déjà la liste déballée
    if (raw == null) return [];
    return raw
        .map((c) => Contact.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Liste des contacts bloqués.
  Future<List<Contact>> listBlocked() async {
    final data = await _api.get('/api/contacts/blocked');
    final raw = data as List?;
    if (raw == null) return [];
    return raw
        .map((c) => Contact.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// Ajoute un contact via son numéro public à 6 chiffres.
  /// ✅ Compatible : Le backend NestJS attend { contactPublicNumber, alias? }
  Future<Contact> add(String publicNumber, {String? alias}) async {
    final data = await _api.post('/api/contacts', {
      'contactPublicNumber': publicNumber,
      if (alias != null && alias.isNotEmpty) 'alias': alias,
    });
    return Contact.fromJson(data);
  }

  /// Ajoute plusieurs contacts en une seule passe (import répertoire téléphonique).
  Future<int> addMany(List<({String publicNumber, String? alias})> entries) async {
    int added = 0;
    for (final e in entries) {
      try {
        await add(e.publicNumber, alias: e.alias);
        added++;
      } on ApiException catch (ex) {
        if (ex.code == 'ALREADY_CONTACT') continue; // déjà présent, on ignore
        rethrow;
      }
    }
    return added;
  }

  /// Met à jour le blocage d'un contact.
  /// ✅ NOUVEAU : PUT /api/contacts/{contactId} avec { isBlocked }
  Future<Contact> setBlocked(String contactId, bool blocked) async {
    final data = await _api.put('/api/contacts/$contactId', {'isBlocked': blocked});
    return Contact.fromJson(data);
  }

  /// Met à jour l'alias d'un contact.
  Future<Contact> setAlias(String contactId, String alias) async {
    final data = await _api.put('/api/contacts/$contactId', {'alias': alias});
    return Contact.fromJson(data);
  }

  /// Supprime un contact.
  Future<void> remove(String contactId) async {
    await _api.delete('/api/contacts/$contactId');
  }

  /// Bloque un contact (raccourci).
  Future<Contact> block(String contactId) => setBlocked(contactId, true);

  /// Débloque un contact (raccourci).
  Future<Contact> unblock(String contactId) => setBlocked(contactId, false);
}