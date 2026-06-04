import 'dart:convert';

import 'package:http/http.dart' as http;

import 'remote_vision_config.dart';
import 'remote_vision_schemas.dart';

/// Thin HTTP wrapper for the local Python vision server. Exposed as a
/// dependency so tests can inject a fake without touching real sockets.
///
/// Privacy: this client makes plain-HTTP requests to the URL configured
/// in [RemoteVisionConfig]. The server is expected to live on the user's
/// own LAN. Frames (Phase 5.0.1) and frame metadata (Phase 5.0) leave
/// the device only by way of this client and only to that URL.
abstract class RemoteVisionClient {
  Future<bool> health();
  Future<RemoteDetectResponse> detect(RemoteDetectRequest request);
  void close();
}

class HttpRemoteVisionClient implements RemoteVisionClient {
  HttpRemoteVisionClient({
    required this.config,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  final RemoteVisionConfig config;
  final http.Client _http;

  Uri _uri(String path) => Uri.parse('${config.baseUrl}$path');

  @override
  Future<bool> health() async {
    try {
      final r = await _http
          .get(_uri('/health'))
          .timeout(config.requestTimeout);
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<RemoteDetectResponse> detect(RemoteDetectRequest request) async {
    final http.Response r;
    try {
      r = await _http
          .post(
            _uri('/detect'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(request.toJson()),
          )
          .timeout(config.requestTimeout);
    } catch (e) {
      throw RemoteVisionException('Request failed: $e');
    }
    if (r.statusCode != 200) {
      throw RemoteVisionException(
        'Server returned ${r.statusCode}: ${r.reasonPhrase}',
      );
    }
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(r.body) as Map<String, dynamic>;
    } catch (e) {
      throw RemoteVisionException('Malformed JSON: $e');
    }
    try {
      return RemoteDetectResponse.fromJson(json);
    } catch (e) {
      throw RemoteVisionException('Unexpected schema: $e');
    }
  }

  @override
  void close() => _http.close();
}
