import 'package:shared_preferences/shared_preferences.dart';

/// Centralized token storage with in-memory cache.
/// On Flutter web, SharedPreferences can be unreliable in debug mode;
/// the in-memory cache ensures the token is available during the same session.
class TokenStorage {
  TokenStorage._();
  static final TokenStorage _instance = TokenStorage._();
  static TokenStorage get instance => _instance;

  String? _inMemoryToken;

  /// Set the auth token (saves to memory + SharedPreferences).
  Future<void> setToken(String token) async {
    _inMemoryToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  /// Get the auth token (memory first, then SharedPreferences).
  Future<String?> getToken() async {
    if (_inMemoryToken != null && _inMemoryToken!.isNotEmpty) {
      return _inMemoryToken;
    }
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null && token.isNotEmpty) {
      _inMemoryToken = token;
    }
    return token;
  }

  /// Clear the token (logout).
  Future<void> clearToken() async {
    _inMemoryToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }
}
