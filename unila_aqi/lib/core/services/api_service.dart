import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Base configuration
  static const String baseUrl = AppConstants.apiBaseUrl;
  static const Duration timeout = Duration(seconds: 30);

  // HTTP client
  final http.Client _client = http.Client();

  // Headers
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

  // Generic request method
  Future<http.Response> _request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    final headers = await _getHeaders();
    final uri = Uri.parse('$baseUrl/$endpoint').replace(queryParameters: queryParams);

    try {
      switch (method) {
        case 'GET':
          return await _client.get(uri, headers: headers).timeout(timeout);
        case 'POST':
          return await _client.post(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(timeout);
        case 'PUT':
          return await _client.put(
            uri,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          ).timeout(timeout);
        case 'DELETE':
          return await _client.delete(uri, headers: headers).timeout(timeout);
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // API Methods
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

  // Response handler
  dynamic _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    final responseBody = response.body;

    try {
      final jsonResponse = jsonDecode(responseBody);

      if (statusCode >= 200 && statusCode < 300) {
        return jsonResponse;
      } else {
        final errorMessage = jsonResponse['message'] ?? 'Request failed with status $statusCode';
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
  
  // REAL: Get all buildings from database
  Future<dynamic> getBuildings() async {
    return await get('buildings');
  }

  // REAL: Get single building by ID
  Future<dynamic> getBuildingById(String id) async {
    return await get('buildings/$id');
  }

  // REAL: Create building
  Future<dynamic> createBuilding(Map<String, dynamic> data) async {
    return await post('buildings', data);
  }

  // REAL: Update building
  Future<dynamic> updateBuilding(String id, Map<String, dynamic> data) async {
    return await put('buildings/$id', data);
  }

  // REAL: Delete building
  Future<dynamic> deleteBuilding(String id) async {
    return await delete('buildings/$id');
  }

  // REAL: Get all rooms from database
  Future<dynamic> getRooms() async {
    return await get('rooms');
  }

  // REAL: Get single room by ID
  Future<dynamic> getRoomById(String id) async {
    return await get('rooms/$id');
  }

  // REAL: Create room
  Future<dynamic> createRoom(Map<String, dynamic> data) async {
    return await post('rooms', data);
  }

  // REAL: Update room
  Future<dynamic> updateRoom(String id, Map<String, dynamic> data) async {
    return await put('rooms/$id', data);
  }

  // REAL: Delete room
  Future<dynamic> deleteRoom(String id) async {
    return await delete('rooms/$id');
  }

  // REAL: Get all IoT devices
  Future<dynamic> getIoTDevices() async {
    return await get('iot-devices');
  }

  // REAL: Get single IoT device
  Future<dynamic> getIoTDeviceById(String id) async {
    return await get('iot-devices/$id');
  }

  // REAL: Create IoT device
  Future<dynamic> createIoTDevice(Map<String, dynamic> data) async {
    return await post('iot-devices', data);
  }

  // REAL: Update IoT device
  Future<dynamic> updateIoTDevice(String id, Map<String, dynamic> data) async {
    return await put('iot-devices/$id', data);
  }

  // REAL: Delete IoT device
  Future<dynamic> deleteIoTDevice(String id) async {
    return await delete('iot-devices/$id');
  }

  // REAL: Get sensor data for room
  Future<dynamic> getSensorData(String roomId, {String range = '24h'}) async {
    return await get('sensor-data/$roomId', queryParams: {'range': range});
  }

  // ==================== TEST/DEBUG ENDPOINTS ====================
  // (Keep for debugging but not used in production)
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

  // Dispose
  void dispose() {
    _client.close();
  }
}