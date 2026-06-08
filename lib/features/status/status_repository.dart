import '../../core/authed_api.dart';
import '../../models/status.dart';

class StatusRepository {
  StatusRepository(this._api);
  final AuthedApi _api;

  Future<StatusFeed> feed() async {
    final data = await _api.get("/api/statuses");
    return StatusFeed.fromJson(data);
  }

  /// Publie un statut texte avec couleur de fond (hex #RRGGBB).
  Future<void> createText(String text, String bgColor) async {
    await _api.post("/api/statuses", {
      "type": "TEXT",
      "text": text,
      "bgColor": bgColor,
    });
  }

  Future<void> markViewed(String statusId) async {
    await _api.post("/api/statuses/$statusId/view", {});
  }

  Future<void> delete(String statusId) async {
    await _api.delete("/api/statuses/$statusId");
  }
}
