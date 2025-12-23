import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _apiService = ApiService();

  // Check if admin is already registered
  Future<bool> isAdminRegistered() async {
    try {
      final response = await _apiService.checkAdminRegistered();
      return response['isRegistered'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // Admin login
  Future<Map<String, dynamic>> loginAdmin(String username, String password) async {
    try {
      final response = await _apiService.adminLogin(username, password);
      
      if (response['success'] == true) {
        await _saveAuthData(response);
      }
      
      return response;
    } catch (e) {
      rethrow;
    }
  }

  // Save authentication data
  Future<void> _saveAuthData(Map<String, dynamic> response) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString('auth_token', response['token']);
    await prefs.setString('user_id', response['user']['id']);
    await prefs.setString('username', response['user']['username']);
    await prefs.setString('role', response['user']['role']);
    await prefs.setBool('is_logged_in', true);
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('is_logged_in') ?? false;
  }

  // Get current user
  Future<Map<String, dynamic>> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    
    return {
      'id': prefs.getString('user_id'),
      'username': prefs.getString('username'),
      'role': prefs.getString('role'),
    };
  }

  // Get auth token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('username');
    await prefs.remove('role');
    await prefs.setBool('is_logged_in', false);
  }

  // Change password
  Future<Map<String, dynamic>> changePassword(
    String oldPassword,
    String newPassword,
  ) async {
    try {
      final token = await getToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      // This would call your backend API
      // For now, return a mock response
      return {
        'success': true,
        'message': 'Password changed successfully',
      };
    } catch (e) {
      rethrow;
    }
  }
}