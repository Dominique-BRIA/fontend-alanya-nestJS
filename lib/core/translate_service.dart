import 'dart:convert';
import 'package:http/http.dart' as http;
class TranslateService {
  TranslateService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  static const String _defaultHost = 'https://libretranslate.com';
  Future<String> translate({required String text, required String target, String source = 'auto', String? host}) async {
    final endpoint = Uri.parse('${host ?? _defaultHost}/translate');
    final res = await _client.post(endpoint, headers: {'Content-Type': 'application/json'}, body: jsonEncode({'q': text, 'source': source, 'target': target, 'format': 'text'}));
    if (res.statusCode != 200) throw Exception('Translate failed: ${res.statusCode}');
    final data = jsonDecode(res.body);
    if (data is Map && data['translatedText'] is String) return data['translatedText'] as String;
    throw Exception('Invalid translate response');
  }
  void dispose() => _client.close();
}
