import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/token_storage.dart';
import '../utils/roles.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  User? _user;
  bool _isLoading = false;
  String? _error;

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  bool get isAdmin => isAdminRole(_user?.role);
  bool get isManager => isManagerRole(_user?.role);
  bool get isAdminLike => isAdminLikeRole(_user?.role);
  bool get isSupervisor => isSupervisorRole(_user?.role);
  bool get isFinance => isFinanceRole(_user?.role);

  // Aliases to avoid clash with top-level imports in getters
  static bool isAdminRole(String? r) => normalizeRole(r) == 'admin';
  static bool isManagerRole(String? r) => normalizeRole(r) == 'manager';
  static bool isAdminLikeRole(String? r) {
    final n = normalizeRole(r);
    return n == 'admin' || n == 'manager';
  }
  static bool isSupervisorRole(String? r) => normalizeRole(r) == 'supervisor';
  static bool isFinanceRole(String? r) => normalizeRole(r) == 'finance';

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/auth/login', {
        'email': email,
        'password': password,
      });

      if (response['success']) {
        final token = response['token'];
        final userData = response['data'];

        // Save token (memory + SharedPreferences) and user data
        await TokenStorage.instance.setToken(token);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userRole', userData['role'] ?? 'user');
        await prefs.setString('userId', userData['id'] ?? '');

        _user = User.fromJson(userData);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = ApiService.traduireMessage(response['message'] ?? 'Login failed');
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = ApiService.traduireMessage(e.toString().replaceAll('Exception: ', ''));
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await TokenStorage.instance.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userRole');
    await prefs.remove('userId');

    _user = null;
    notifyListeners();
  }

  Future<bool> loadUser() async {
    try {
      final response = await _apiService.get('/auth/me');
      if (response['success']) {
        final userData = response['data'];
        _user = User.fromJson(userData);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userRole', userData['role'] ?? 'user');
        await prefs.setString('userId', userData['id'] ?? '');
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      await TokenStorage.instance.clearToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('userRole');
      await prefs.remove('userId');
      _user = null;
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

