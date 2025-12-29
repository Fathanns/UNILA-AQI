import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/room.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';

class RoomRepository {
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
  
  // Get all rooms
  Future<List<Room>> getRooms() async {
  try {
    print('📡 Fetching rooms from: ${AppConstants.apiBaseUrl}/rooms');
    
    // Coba dengan token terlebih dahulu (untuk admin)
    final headers = await _getHeaders();
    
    print('🔑 Using token: ${headers.containsKey('Authorization') ? 'YES' : 'NO'}');
    
    final response = await http.get(
      Uri.parse('${AppConstants.apiBaseUrl}/rooms'),
      headers: headers,
    );
    
    print('📊 API Status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      print('✅ API Success: ${jsonResponse['success']}');
      
      if (jsonResponse['success'] == true) {
        final List<dynamic> data = jsonResponse['data'];
        final rooms = data.map((json) => Room.fromJson(json)).toList();
        
        print('🎯 Loaded ${rooms.length} rooms');
        return rooms;
      } else {
        throw Exception(jsonResponse['message'] ?? 'Failed to fetch rooms');
      }
    } else if (response.statusCode == 401) {
      print('⚠️ Token invalid or expired, trying without token...');
      
      // Coba tanpa token (untuk user mode)
      final publicResponse = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/rooms'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      
      if (publicResponse.statusCode == 200) {
        final jsonResponse = jsonDecode(publicResponse.body);
        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'];
          final rooms = data.map((json) => Room.fromJson(json)).toList();
          
          print('🎯 Loaded ${rooms.length} rooms without token');
          return rooms;
        }
      }
      
      throw Exception('Access denied. Please login as admin or try user mode.');
    } else {
      print('❌ API Error: ${response.statusCode} - ${response.body}');
      throw Exception('Failed to fetch rooms: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Room Repository Error: $e');
    rethrow;
  }
}
  
  // Get room by ID
  Future<Room> getRoomById(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/rooms/$id'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          return Room.fromJson(jsonResponse['data']);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to fetch room');
        }
      } else {
        throw Exception('Failed to fetch room: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Create room
  Future<Room> createRoom({
    required String name,
    required String buildingId,
    String dataSource = 'simulation',
    String? iotDeviceId,
    bool isActive = true,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'name': name,
        'buildingId': buildingId,
        'dataSource': dataSource,
        'iotDeviceId': iotDeviceId,
        'isActive': isActive,
      });
      
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/rooms'),
        headers: headers,
        body: body,
      );
      
      if (response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          return Room.fromJson(jsonResponse['data']);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to create room');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to create room');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Update room
  Future<Room> updateRoom({
    required String id,
    required String name,
    required String buildingId,
    String dataSource = 'simulation',
    String? iotDeviceId,
    bool isActive = true,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'name': name,
        'buildingId': buildingId,
        'dataSource': dataSource,
        'iotDeviceId': iotDeviceId,
        'isActive': isActive,
      });
      
      final response = await http.put(
        Uri.parse('${AppConstants.apiBaseUrl}/rooms/$id'),
        headers: headers,
        body: body,
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          return Room.fromJson(jsonResponse['data']);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to update room');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to update room');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Delete room
  Future<void> deleteRoom(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${AppConstants.apiBaseUrl}/rooms/$id'),
        headers: headers,
      );
      
      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to delete room');
      }
    } catch (e) {
      rethrow;
    }
  }
}