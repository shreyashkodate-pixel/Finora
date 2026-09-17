import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'config.dart';

/// Structured API Exception wrapping the RFC error envelope per SRS §3.6.
class ApiException implements Exception {
  final int statusCode;
  final String code;
  final String message;
  final dynamic details;

  ApiException({
    required this.statusCode,
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}

typedef TokenRefreshCallback = Future<bool> Function();

/// Robust HTTP client communicating with the FastAPI backend (/api/v1).
/// Features:
/// - Bearer token injection
/// - Automatic UUIDv4 Idempotency-Key generation on mutations
/// - Transparent 401 retry via registered TokenRefreshCallback
/// - Error envelope parsing (RFC compliance)
class ApiClient {
  final String baseUrl;
  String? _accessToken;
  TokenRefreshCallback? onTokenExpired;

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  String? get accessToken => _accessToken;

  String generateUuid() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  Map<String, String> _buildHeaders({String? idempotencyKey, bool isMutation = false}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    if (isMutation) {
      headers['Idempotency-Key'] = idempotencyKey ?? generateUuid();
    }
    return headers;
  }

  Future<dynamic> _handleResponse(http.Response response, Future<http.Response> Function() retryFn) async {
    // If 401 and refresh callback registered, attempt token refresh and retry once
    if (response.statusCode == 401 && onTokenExpired != null) {
      final refreshed = await onTokenExpired!();
      if (refreshed) {
        final retriedResponse = await retryFn();
        return _parseBody(retriedResponse);
      }
    }
    return _parseBody(response);
  }

  dynamic _parseBody(http.Response response) {
    dynamic decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        decoded = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    // Parse standard error envelope: {"error": {"code": "...", "message": "...", "details": ...}}
    if (decoded is Map<String, dynamic> && decoded.containsKey('error')) {
      final err = decoded['error'];
      if (err is Map<String, dynamic>) {
        throw ApiException(
          statusCode: response.statusCode,
          code: err['code']?.toString() ?? 'HTTP_ERROR',
          message: err['message']?.toString() ?? 'An error occurred.',
          details: err['details'],
        );
      }
    }

    throw ApiException(
      statusCode: response.statusCode,
      code: 'HTTP_${response.statusCode}',
      message: response.reasonPhrase ?? 'Request failed with status ${response.statusCode}',
      details: decoded,
    );
  }

  Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParameters}) async {
    Uri url = Uri.parse('$baseUrl$endpoint');
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final strParams = queryParameters.map((k, v) => MapEntry(k, v.toString()));
      url = url.replace(queryParameters: strParams);
    }
    final response = await http
        .get(url, headers: _buildHeaders())
        .timeout(Duration(milliseconds: AppConfig.requestTimeoutMs));
    return _handleResponse(response, () => http.get(url, headers: _buildHeaders()));
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = _buildHeaders(idempotencyKey: idempotencyKey, isMutation: true);
    final encodedBody = body != null ? jsonEncode(body) : null;
    final response = await http
        .post(url, headers: headers, body: encodedBody)
        .timeout(Duration(milliseconds: AppConfig.requestTimeoutMs));
    return _handleResponse(
      response,
      () => http.post(url, headers: _buildHeaders(isMutation: true), body: encodedBody),
    );
  }

  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = _buildHeaders(isMutation: true);
    final encodedBody = body != null ? jsonEncode(body) : null;
    final response = await http
        .put(url, headers: headers, body: encodedBody)
        .timeout(Duration(milliseconds: AppConfig.requestTimeoutMs));
    return _handleResponse(
      response,
      () => http.put(url, headers: headers, body: encodedBody),
    );
  }

  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = _buildHeaders(isMutation: true);
    final encodedBody = body != null ? jsonEncode(body) : null;
    final response = await http
        .patch(url, headers: headers, body: encodedBody)
        .timeout(Duration(milliseconds: AppConfig.requestTimeoutMs));
    return _handleResponse(
      response,
      () => http.patch(url, headers: headers, body: encodedBody),
    );
  }

  Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = _buildHeaders(isMutation: true);
    final response = await http
        .delete(url, headers: headers)
        .timeout(Duration(milliseconds: AppConfig.requestTimeoutMs));
    return _handleResponse(
      response,
      () => http.delete(url, headers: headers),
    );
  }
}
