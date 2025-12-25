import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/iot_device.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';

class IoTDeviceRepository {
  final StorageService _storage = StorageService();
  
  Future<String?> _getToken() async {
    return _storage.getString('auth_token');
  }
  
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
  
  // Get all IoT devices
  Future<List<IoTDevice>> getDevices() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/iot-devices'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'];
          return data.map((json) => IoTDevice.fromJson(json)).toList();
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to fetch devices');
        }
      } else {
        throw Exception('Failed to fetch devices: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Get device by ID
  Future<IoTDevice> getDeviceById(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/iot-devices/$id'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          return IoTDevice.fromJson(jsonResponse['data']);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to fetch device');
        }
      } else {
        throw Exception('Failed to fetch device: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Create device - HAPUS buildingId parameter
  Future<IoTDevice> createDevice({
    required String name,
    String? description,
    required String apiEndpoint,
    bool isActive = true,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'name': name,
        'description': description,
        'apiEndpoint': apiEndpoint,
        'isActive': isActive,
      });
      
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/iot-devices'),
        headers: headers,
        body: body,
      );
      
      if (response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          return IoTDevice.fromJson(jsonResponse['data']);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to create device');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to create device');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Update device - HAPUS buildingId parameter
  Future<IoTDevice> updateDevice({
    required String id,
    required String name,
    String? description,
    required String apiEndpoint,
    bool isActive = true,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'name': name,
        'description': description,
        'apiEndpoint': apiEndpoint,
        'isActive': isActive,
      });
      
      final response = await http.put(
        Uri.parse('${AppConstants.apiBaseUrl}/iot-devices/$id'),
        headers: headers,
        body: body,
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          return IoTDevice.fromJson(jsonResponse['data']);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to update device');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to update device');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Delete device
  Future<void> deleteDevice(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${AppConstants.apiBaseUrl}/iot-devices/$id'),
        headers: headers,
      );
      
      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to delete device');
      }
    } catch (e) {
      rethrow;
    }
  }
}