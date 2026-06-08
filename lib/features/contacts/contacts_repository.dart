import '../../core/authed_api.dart';
import '../../models/contact.dart';

class ContactsRepository {
  ContactsRepository(this._api);
  final AuthedApi _api;

  /// Recherche un utilisateur par son numéro public à 6 chiffres.
  Future<UserSearchResult> searchByNumber(String number) async {
    final data = await _api.get("/api/users/search?number=$number");
    return UserSearchResult.fromJson(data);
  }

  Future<List<Contact>> list() async {
    final data = await _api.get("/api/contacts");
    return ((data["contacts"] as List?) ?? [])
        .map((c) => Contact.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(String publicNumber, {String? alias}) async {
    await _api.post("/api/contacts", {
      "publicNumber": publicNumber,
      if (alias != null && alias.isNotEmpty) "alias": alias,
    });
  }

  Future<void> setBlocked(String contactId, bool blocked) async {
    await _api.patch("/api/contacts/$contactId", {"isBlocked": blocked});
  }

  Future<void> setAlias(String contactId, String alias) async {
    await _api.patch("/api/contacts/$contactId", {"alias": alias});
  }

  Future<void> remove(String contactId) async {
    await _api.delete("/api/contacts/$contactId");
  }
}
