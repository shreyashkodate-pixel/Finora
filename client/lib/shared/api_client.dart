import 'dart:convert';
import 'package:http/http.dart' as http;

/// Base API client for communicating with the FastAPI backend (/api/v1).
/// Supports JWT authentication interceptor and Idempotency-Key header per SRS §3.6.
class ApiClient {
  final String baseUrl;
  String? _accessToken;

  ApiClient({required this.baseUrl});

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  Map<String, String> _buildHeaders({String? idempotencyKey}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    if (idempotencyKey != null) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    return headers;
  }

  Future<http.Response> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    return await http.get(url, headers: _buildHeaders());
  }

  Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    return await http.post(
      url,
      headers: _buildHeaders(idempotencyKey: idempotencyKey),
      body: body != null ? jsonEncode(body) : null,
    );
  }
}
