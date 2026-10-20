import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';

class ProfileRepository {
  final StorageService _storage = StorageService();

  Future<Map<String, String>> _getHeaders() async {
    final token = _storage.getString('auth_token');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('${AppConstants.apiBaseUrl}/auth/profile'),
      headers: headers,
    );
    final json = jsonDecode(response.body);
    if (response.statusCode == 200 && json['success'] == true) {
      return json;
    }
    throw Exception(json['message'] ?? 'Gagal memuat profil');
  }

  Future<Map<String, dynamic>> updateProfile({
    required String username,
    String? email,
  }) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('${AppConstants.apiBaseUrl}/auth/profile'),
      headers: headers,
      body: jsonEncode({'username': username, 'email': email}),
    );
    final json = jsonDecode(response.body);
    if (response.statusCode == 200 && json['success'] == true) {
      return json;
    }
    throw Exception(json['message'] ?? 'Gagal memperbarui profil');
  }

  Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse('${AppConstants.apiBaseUrl}/auth/change-password'),
      headers: headers,
      body: jsonEncode({
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      }),
    );
    final json = jsonDecode(response.body);
    if (response.statusCode == 200 && json['success'] == true) {
      return json;
    }
    throw Exception(json['message'] ?? 'Gagal mengubah password');
  }
}