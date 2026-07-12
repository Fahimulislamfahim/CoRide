import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  Map<String, dynamic>? _user;
  String? _token;
  bool _isLoading = false;
  String? _error;

  Map<String, dynamic>? get user => _user;
  String? get token => _token;
  bool get isAuthenticated => _token != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Check secure storage for existing session
  Future<bool> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _apiService.getToken();
      if (token == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Quick backend validation test via fetching active rides (protected endpoint)
      final response = await _apiService.get('/rides/active');
      if (response.statusCode == 200) {
        _token = token;
        // In real apps, you'd fetch user details. Here we set basic state.
        // We'll read the cached user info if we stored it, or let the app fetch it.
        // For simplicity, we decode JWT or retrieve user profile. Let's load mock user info from storage or set from state.
        final storedName = await _apiService.getToken() != null ? "DIU Member" : null;
        _user = {
          'name': storedName,
          'email': 'student@diu.edu.bd', // Dummy placeholder until next login updates it
        };
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      print('Auto-login failed: $e');
      await logout();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Register a new user
  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String studentId,
    required String phone,
    required String role,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
        'student_id': studentId,
        'phone': phone,
        'role': role,
      });

      if (response.statusCode == 201) {
        _token = response.data['token'];
        _user = response.data['user'];
        await _apiService.saveToken(_token!);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Login User
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/auth/login', data: {
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        _token = response.data['token'];
        _user = response.data['user'];
        await _apiService.saveToken(_token!);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Logout User
  Future<void> logout() async {
    _token = null;
    _user = null;
    await _apiService.clearToken();
    notifyListeners();
  }
}
