import '../../core/authed_api.dart';

/// API d'enregistrement des jetons FCM.
class PushRepository {
  PushRepository(this._api);

  final AuthedApi _api;

  /// Enregistre un device pour les notifications push.
  /// ✅ Compatible : POST /api/push/register
  Future<void> register(String token, String platform) async {
    await _api.post('/api/push/register', {'token': token, 'platform': platform});
  }

  /// Liste les devices enregistrés.
  /// ✅ NOUVEAU : GET /api/push/devices
  Future<List<Map<String, dynamic>>> listDevices() async {
    final data = await _api.get('/api/push/devices');
    return (data as List).cast<Map<String, dynamic>>();
  }

  /// Supprime un device.
  /// ✅ NOUVEAU : DELETE /api/push/devices/{deviceId} (au lieu de DELETE /api/push/register?token=)
  Future<void> unregister(String deviceId) async {
    await _api.delete('/api/push/devices/$deviceId');
  }

  /// Supprime un device par token (helper).
  Future<void> unregisterByToken(String token) async {
    final devices = await listDevices();
    final device = devices.where((d) => d['token'] == token).firstOrNull;
    if (device != null) {
      await unregister(device['id'] as String);
    }
  }
}