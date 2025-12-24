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

  // Specific API endpoints
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

  Future<dynamic> getTestBuildings() async {
    return await get('test/buildings');
  }

  Future<dynamic> getTestRooms() async {
    return await get('test/rooms');
  }

  Future<dynamic> getRoomDetails(String roomId) async {
    return await get('rooms/$roomId');
  }

  Future<dynamic> getSensorData(String roomId, {String range = '24h'}) async {
    return await get('sensor-data/$roomId', queryParams: {'range': range});
  }

  // API Methods untuk data historis
Future<dynamic> getSensorDataHistory(String roomId, {String range = '24h'}) async {
  try {
    // Untuk sementara, return mock data karena backend belum selesai
    // Di Phase 2 nanti akan diimplementasi dengan endpoint real
    await Future.delayed(const Duration(seconds: 1));
    
    // Generate mock data
    final now = DateTime.now();
    final List<Map<String, dynamic>> mockData = [];
    
    for (int i = 0; i < 24; i++) {
      final timestamp = now.subtract(Duration(hours: 23 - i));
      mockData.add({
        'timestamp': timestamp.toIso8601String(),
        'aqi': 20 + (i * 3) + (DateTime.now().millisecond % 30),
        'pm25': 10 + (i * 1.5) + (DateTime.now().millisecond % 10),
        'pm10': 20 + (i * 2) + (DateTime.now().millisecond % 15),
        'temperature': 22 + (DateTime.now().millisecond % 8).toDouble(),
        'humidity': 50 + (DateTime.now().millisecond % 20).toDouble(),
      });
    }
    
    return {
      'success': true,
      'data': mockData,
      'range': range,
    };
  } catch (e) {
    throw Exception('Failed to load historical data: $e');
  }
}

  // Dispose
  void dispose() {
    _client.close();
  }
}