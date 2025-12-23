import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  Map<String, dynamic>? _currentUser;
  bool _isLoggedIn = false;
  bool _isLoading = false;
  
  Map<String, dynamic>? get currentUser => _currentUser;
  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  bool get isAdmin => _currentUser?['role'] == 'admin';
  
  // Initialize auth state
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _isLoggedIn = await _authService.isLoggedIn();
      if (_isLoggedIn) {
        _currentUser = await _authService.getCurrentUser();
      }
    } catch (e) {
      _isLoggedIn = false;
      _currentUser = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Login
  Future<void> login(String username, String password, String role) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final response = await _authService.loginAdmin(username, password);
      
      if (response['success'] == true) {
        _currentUser = response['user'];
        _isLoggedIn = true;
      } else {
        throw Exception(response['message'] ?? 'Login failed');
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Logout
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _authService.logout();
      _currentUser = null;
      _isLoggedIn = false;
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Change password
  Future<void> changePassword(String oldPassword, String newPassword) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _authService.changePassword(oldPassword, newPassword);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}