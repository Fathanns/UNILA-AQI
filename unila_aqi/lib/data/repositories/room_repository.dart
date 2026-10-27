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

  Future<List<Room>> getRooms() async {
    try {
      print('📡 Fetching rooms from: ${AppConstants.apiBaseUrl}/rooms');

      final headers = await _getHeaders();

      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/rooms'),
        headers: headers,
      );

      print('📊 API Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'];
          final rooms = data.map((json) => Room.fromJson(json)).toList();
          return rooms;
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to fetch rooms');
        }
      } else if (response.statusCode == 401) {
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
            return data.map((json) => Room.fromJson(json)).toList();
          }
        }

        throw Exception('Access denied. Please login as admin or try user mode.');
      } else {
        // FIXED: ganti prefix 'Failed to fetch' → 'Rooms request failed'
        // agar tidak memicu Helpers.isNetworkError (false positive).
        throw Exception('Rooms request failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Room Repository Error: $e');
      rethrow;
    }
  }

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
        // FIXED: prefix 'Failed to fetch' → 'Room request failed'
        throw Exception('Room request failed: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Room> createRoom({
    required String name,
    required String buildingId,
    String dataSource = 'simulation',
    String? iotDeviceId,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'name': name,
        'buildingId': buildingId,
        'dataSource': dataSource,
        'iotDeviceId': iotDeviceId,
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

  Future<Room> updateRoom({
    required String id,
    required String name,
    required String buildingId,
    String dataSource = 'simulation',
    String? iotDeviceId,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'name': name,
        'buildingId': buildingId,
        'dataSource': dataSource,
        'iotDeviceId': iotDeviceId,
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