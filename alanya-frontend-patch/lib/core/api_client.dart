import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show MediaType;
import 'server_config.dart';

/// Exception levée quand l'API renvoie une erreur (status >= 400).
class ApiException implements Exception {
  final int statusCode;
  final String message;
  final String? code;

  ApiException(this.statusCode, this.message, [this.code]);

  @override
  String toString() => message;
}

/// Client HTTP minimal vers le backend Alanya (NestJS).
/// 
/// Le backend NestJS enveloppe toutes les réponses dans :
/// { "data": {...}, "timestamp": "..." }
/// Cette classe déballé automatiquement le champ "data".
class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBaseUrl;

  final String baseUrl;

  static String get _defaultBaseUrl => ServerConfig.apiBase;

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body, {
    String? bearer,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers(bearer),
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> get(String path, {String? bearer}) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers(bearer));
    return _decode(res);
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body, {
    String? bearer,
  }) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers(bearer),
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body, {
    String? bearer,
  }) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers(bearer),
      body: jsonEncode(body),
    );
    return _decode(res);
  }

  Future<Map<String, dynamic>> delete(String path, {String? bearer}) async {
    final res = await http.delete(Uri.parse('$baseUrl$path'), headers: _headers(bearer));
    return _decode(res);
  }

  /// Upload multipart d'un fichier (champ "file"), avec champs additionnels optionnels.
  Future<Map<String, dynamic>> uploadBytes(
    String path,
    Uint8List bytes,
    String filename,
    String mimeType, {
    String? bearer,
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    if (bearer != null) request.headers['Authorization'] = 'Bearer $bearer';
    if (fields != null) request.fields.addAll(fields);
    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: filename,
      contentType: MediaType.parse(mimeType),
    ));
    final streamed = await request.send();
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }

  Map<String, String> _headers(String? bearer) => {
    'Content-Type': 'application/json',
    if (bearer != null) 'Authorization': 'Bearer $bearer',
  };

  /// Décode la réponse et déballé l'enveloppe NestJS { data: ..., timestamp: ... }
  Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> data = {};
    try {
      if (res.body.isNotEmpty) {
        data = jsonDecode(res.body) as Map<String, dynamic>;
      }
    } catch (_) {
      // body non-JSON (ex. HTML d'erreur)
      if (res.statusCode >= 400) {
        throw ApiException(res.statusCode, 'Erreur serveur ${res.statusCode}');
      }
    }

    if (res.statusCode >= 400) {
      // Format backend NestJS : { error: { message, code }, statusCode, timestamp }
      final err = data['error'] as Map<String, dynamic>?;
      final msg = (err?['message'] as String?) ?? (data['message'] as String?) ?? 'Erreur ${res.statusCode}';
      final code = err?['code'] as String? ?? data['code'] as String?;
      throw ApiException(res.statusCode, msg, code);
    }

    // ✅ NOUVEAU : Déballer l'enveloppe NestJS { data: ..., timestamp: ... }
    if (data.containsKey('data')) {
      return data['data'] as Map<String, dynamic>;
    }
    return data;
  }
}