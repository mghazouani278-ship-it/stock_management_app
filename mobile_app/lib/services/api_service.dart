import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'api_host.dart' if (dart.library.io) 'api_host_io.dart' as host;
import 'api_locale.dart';
import 'token_storage.dart';

class ApiService {
  // Production: set apiBaseUrlOverride in api_config.dart
  // Local: http://localhost:5000/api (web) | http://127.0.0.1:5000/api (mobile)
  static String get baseUrl =>
      apiBaseUrlOverride ?? 'http://${host.apiHost}:5000/api';
  
  // Get auth token (memory cache + SharedPreferences)
  Future<String?> _getToken() async {
    return TokenStorage.instance.getToken();
  }

  // Make authenticated request
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      'Accept-Language': ApiLocale.languageCode,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Generic GET request
  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    try {
      Uri uri = Uri.parse('$baseUrl$endpoint');
      if (queryParams != null) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final response = await http.get(
        uri,
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    } catch (e) {
      throw Exception(traduireMessage(e.toString()));
    }
  }

  // Generic POST request
  Future<dynamic> post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      ).timeout(const Duration(seconds: 15));

      return _handleResponse(response);
    } catch (e) {
      throw Exception(traduireMessage(e.toString()));
    }
  }

  // Generic PUT request
  Future<dynamic> put(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
        body: jsonEncode(data),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception(traduireMessage(e.toString()));
    }
  }

  // Upload image (multipart)
  Future<dynamic> uploadImage(String endpoint, List<int> fileBytes, String filename) async {
    try {
      final token = await _getToken();
      final uri = Uri.parse('$baseUrl$endpoint');
      final request = http.MultipartRequest('POST', uri);
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept-Language'] = ApiLocale.languageCode;
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        fileBytes,
        filename: filename,
      ));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      return _handleResponse(response);
    } catch (e) {
      throw Exception(traduireMessage(e.toString()));
    }
  }

  // Generic DELETE request
  Future<dynamic> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: await _getHeaders(),
      );

      return _handleResponse(response);
    } catch (e) {
      throw Exception(traduireMessage(e.toString()));
    }
  }

  static String traduireMessage(String msg) {
    final m = msg.replaceAll('Exception: ', '');
    final ml = m.toLowerCase();
    if (m.contains('TimeoutException') || m.contains('Connection timed out')) {
      return 'Unable to reach the server. Run start.bat to start the backend automatically.';
    }
    if (m.contains('Network error') || m.contains('Failed to fetch') || m.contains('Failed host lookup') || m.contains('Connection refused') || m.contains('SocketException')) {
      return 'Unable to reach the server. Run start.bat to start the backend automatically.';
    }
    if (m.contains('Invalid credentials')) return 'Invalid credentials.';
    if (m.contains('deactivated')) return 'Your account has been deactivated.';
    if (ml.contains('not authorized') || ml.contains('is not authorized') || ml.contains('forbidden') || ml.contains('unauthorized')) {
      return 'Access denied. Contact your admin.';
    }
    if (m.contains('User already exists')) return 'This user already exists.';
    if (m.contains('Store name already exists') || m.contains('Project name already exists')) return 'This name already exists.';
    if (m.contains('Please provide')) return 'Please fill in all required fields.';
    if (m.contains('Not found')) return 'Not found.';
    if (m.contains('Route not found')) return 'API route not found. Run start.bat to start the backend.';
    if (m.contains('An error occurred')) return 'An error occurred.';
    if (m.contains('exceeds allowed quantity')) return 'Quantité supplémentaire : approbation admin requise. Redémarrez le backend (start.ps1) et réessayez.';
    if (m.contains('HTML instead of JSON') || m.contains('Invalid server response')) {
      return 'Unable to reach the server. Run start.bat to start the backend automatically.';
    }
    return m;
  }

  // Handle HTTP response
  dynamic _handleResponse(http.Response response) {
    final body = response.body;
    if (body.isEmpty) {
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return <String, dynamic>{};
      }
      throw Exception('Server returned empty response (${response.statusCode})');
    }
    if (body.trimLeft().startsWith('<')) {
      throw Exception(
        'Server returned HTML instead of JSON. '
        'Check that the backend is running on port 5000 and the API URL is correct.',
      );
    }
    dynamic responseData;
    try {
      responseData = jsonDecode(body);
    } catch (_) {
      throw Exception(
        'Invalid server response. '
        'Ensure the backend is running and the API is reachable.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    } else {
      throw Exception(traduireMessage(responseData['message'] ?? 'An error occurred'));
    }
  }
}

