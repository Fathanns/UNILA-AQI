import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  static const String baseUrl = AppConstants.apiBaseUrl;
  static const Duration timeout = Duration(seconds: 30);

  final http.Client _client = http.Client();

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<http.Response> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final headers = await _getHeaders();
    final uri =
        Uri.parse('$baseUrl/$endpoint').replace(queryParameters: queryParams);

    try {
      switch (method) {
        case 'GET':
          return await _client.get(uri, headers: headers).timeout(timeout);
        case 'POST':
          return await _client
              .post(
                uri,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(timeout);
        case 'PUT':
          return await _client
              .put(
                uri,
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(timeout);
        case 'DELETE':
          return await _client.delete(uri, headers: headers).timeout(timeout);
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<bool> checkServerHealth() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/simple-test'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    final response = await _request('GET', endpoint, queryParams: queryParams);
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final response = await _request('POST', endpoint, body: body);
    return _handleResponse(response);
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final response = await _request('PUT', endpoint, body: body);
    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    final response = await _request('DELETE', endpoint);
    return _handleResponse(response);
  }

  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    final responseBody = response.body;

    try {
      final jsonResponse = jsonDecode(responseBody);

      if (statusCode >= 200 && statusCode < 300) {
        return jsonResponse;
      } else {
        final errorMessage =
            jsonResponse['message'] ?? 'Request failed with status $statusCode';
        throw Exception(errorMessage);
      }
    } catch (e) {
      if (statusCode >= 200 && statusCode < 300) {
        return responseBody;
      }
      throw Exception('Failed to parse response: $e');
    }
  }

  // ==================== AUTH ENDPOINTS ====================
  Future<dynamic> checkAdminRegistered() async {
    return await get('auth/check-admin');
  }

  Future<dynamic> adminLogin(String username, String password) async {
    return await post('auth/login', {
      'username': username,
      'password': password,
      'role': 'admin',
    });
  }

  Future<dynamic> getUserProfile() async {
    return await get('auth/profile');
  }

  // ==================== REAL DATA ENDPOINTS ====================

  Future<dynamic> getBuildings() async {
    return await get('buildings');
  }

  Future<dynamic> getBuildingById(String id) async {
    return await get('buildings/$id');
  }

  Future<dynamic> createBuilding(Map<String, dynamic> data) async {
    return await post('buildings', data);
  }

  Future<dynamic> updateBuilding(String id, Map<String, dynamic> data) async {
    return await put('buildings/$id', data);
  }

  Future<dynamic> deleteBuilding(String id) async {
    return await delete('buildings/$id');
  }

  Future<dynamic> getRooms() async {
    return await get('rooms');
  }

  Future<dynamic> getRoomById(String id) async {
    return await get('rooms/$id');
  }

  Future<dynamic> createRoom(Map<String, dynamic> data) async {
    return await post('rooms', data);
  }

  Future<dynamic> updateRoom(String id, Map<String, dynamic> data) async {
    return await put('rooms/$id', data);
  }

  Future<dynamic> deleteRoom(String id) async {
    return await delete('rooms/$id');
  }

  Future<dynamic> getIoTDevices() async {
    return await get('iot-devices');
  }

  Future<dynamic> getIoTDeviceById(String id) async {
    return await get('iot-devices/$id');
  }

  Future<dynamic> createIoTDevice(Map<String, dynamic> data) async {
    return await post('iot-devices', data);
  }

  Future<dynamic> updateIoTDevice(String id, Map<String, dynamic> data) async {
    return await put('iot-devices/$id', data);
  }

  Future<dynamic> deleteIoTDevice(String id) async {
    return await delete('iot-devices/$id');
  }

  // FIXED: sertakan statusCode di response agar pemanggil bisa membedakan
  // 401 (auth) vs 5xx (server error) vs network error.
  Future<dynamic> getSensorData(String roomId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/sensor-data/$roomId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'data': [],
          'error': 'Sensor data request failed: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': [],
        'error': e.toString(),
      };
    }
  }

  // ==================== TEST/DEBUG ENDPOINTS ====================
  Future<dynamic> getTestBuildings() async {
    return await get('test/buildings');
  }

  Future<dynamic> getTestRooms() async {
    return await get('test/rooms');
  }

  Future<dynamic> getTestStatus() async {
    return await get('test/status');
  }

  // ==================== UTILITY ENDPOINTS ====================
  Future<dynamic> seedSampleData() async {
    return await post('seed/seed', {});
  }

  Future<dynamic> clearSampleData() async {
    return await post('seed/clear', {});
  }

  Future<dynamic> syncBuildingNames() async {
    return await post('rooms/sync-building-names', {});
  }

  Future<dynamic> forceRefresh() async {
    try {
      final response = await _request('POST', 'force-refresh', body: {});
      final body = jsonDecode(response.body);

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          body is Map &&
          body['success'] == true) {
        return body;
      }

      return {
        'success': false,
        'message': (body is Map ? body['message']?.toString() : null) ??
            'Force refresh failed (${response.statusCode})',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Gagal force refresh: $e',
      };
    }
  }

  // FIXED: prefix error diubah dari 'Failed to fetch history data'
  // menjadi 'History request failed' agar tidak memicu false positive
  // di Helpers.isNetworkError. Sertakan statusCode agar pemanggil
  // dapat membedakan 401 (butuh login) vs error lain.
  Future<dynamic> getSensorHistory(String roomId, String date,
      {int interval = 30}) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse(
            '$baseUrl/sensor-data/$roomId/history?date=$date&interval=$interval'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse;
      } else {
        return {
          'success': false,
          'data': [],
          'error': 'History request failed: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': [],
        'error': e.toString(),
      };
    }
  }

  // FIXED: prefix error + statusCode (konsisten dengan method lain).
  Future<dynamic> get24HoursSensorData(String roomId) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/sensor-data/$roomId'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'data': [],
          'error': '24h data request failed: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'data': [],
        'error': e.toString(),
      };
    }
  }

  Future<dynamic> forgotPassword(String email) async {
    return await post('auth/forgot-password', {'email': email});
  }

  Future<dynamic> resetPasswordWithCode({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    return await post('auth/reset-password', {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
  }

  Future<dynamic> resendResetCode(String email) async {
    return await post('auth/resend-reset-code', {'email': email});
  }

  void dispose() {
    _client.close();
  }
    Future<dynamic> getMonthlyTrend(
    String roomId, {
    required int year,
    required int month,
  }) async {
    try {
      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('$baseUrl/sensor-data/$roomId/monthly?year=$year&month=$month'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return {
          'success': false,
          'error': 'Monthly trend request failed: ${response.statusCode}',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
}

