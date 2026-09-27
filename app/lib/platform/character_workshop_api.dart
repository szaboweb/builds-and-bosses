import 'dart:convert';

import 'package:http/http.dart' as http;

class CharacterWorkshopApi {
  CharacterWorkshopApi({http.Client? client})
    : _client = client ?? http.Client();

  static const baseUrl = String.fromEnvironment(
    'CHARACTER_WORKSHOP_URL',
    defaultValue: 'http://127.0.0.1:8765',
  );

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<dynamic> _request(
    String method,
    String path, [
    Object? body,
    Duration timeout = const Duration(seconds: 30),
  ]) async {
    final request = http.Request(method, _uri(path));
    request.headers['content-type'] = 'application/json';
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed);
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map ? decoded['detail'] : null;
      throw CharacterWorkshopException(
        message?.toString() ?? 'Workshop API failed (${response.statusCode})',
      );
    }
    return decoded;
  }

  Future<Map<String, dynamic>> health() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/health') as Map);

  Future<List<Map<String, dynamic>>> listProjects() async =>
      (await _request('GET', '/api/projects') as List)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();

  Future<Map<String, dynamic>> createProject(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
        await _request('POST', '/api/projects', body) as Map,
      );

  Future<Map<String, dynamic>> updateProject(
    String id,
    Map<String, dynamic> body,
  ) async => Map<String, dynamic>.from(
    await _request('PUT', '/api/projects/$id', body) as Map,
  );

  Future<Map<String, dynamic>> generate(String id, {int? seed}) async =>
      Map<String, dynamic>.from(
        await _request('POST', '/api/projects/$id/generate', {
          ...?(seed == null ? null : {'seed': seed}),
        }) as Map,
      );

  Future<Map<String, dynamic>> job(String id, String promptId) async =>
      Map<String, dynamic>.from(
        await _request('GET', '/api/projects/$id/jobs/$promptId') as Map,
      );

  Future<Map<String, dynamic>> approve(String id, String promptId) async =>
      Map<String, dynamic>.from(
        await _request('POST', '/api/projects/$id/approve/$promptId') as Map,
      );

  Future<Map<String, dynamic>> animate(
    String id,
    List<Map<String, dynamic>> parts,
  ) async => Map<String, dynamic>.from(
    await _request('POST', '/api/projects/$id/animate', {
      'parts': parts,
    }, const Duration(minutes: 12)) as Map,
  );

  Uri candidateImageUri(String id, String promptId, int revision) =>
      _uri('/api/projects/$id/jobs/$promptId/images/0?revision=$revision');

  Uri approvedImageUri(String id, int revision) =>
      _uri('/api/projects/$id/approved.png?revision=$revision');

  Uri animationSheetUri(String id, int revision) =>
      _uri('/api/projects/$id/animation/sheet?revision=$revision');

  Uri animationContactSheetUri(String id, int revision) =>
      _uri('/api/projects/$id/animation/contact-sheet?revision=$revision');

  Uri animationQualityUri(String id) =>
      _uri('/api/projects/$id/animation/quality');

  void close() => _client.close();
}

class CharacterWorkshopException implements Exception {
  const CharacterWorkshopException(this.message);

  final String message;

  @override
  String toString() => message;
}
