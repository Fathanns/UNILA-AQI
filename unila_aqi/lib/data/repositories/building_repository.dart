// File: lib/data/repositories/building_repository.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/building.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/storage_service.dart';

class BuildingRepository {
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
  
  // Get all buildings
  Future<List<Building>> getBuildings() async {
    try {
      print('📡 Fetching buildings from: ${AppConstants.apiBaseUrl}/buildings');
      
      final headers = await _getHeaders();
      print('🔑 Token available: ${headers.containsKey('Authorization')}');
      
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/buildings'),
        headers: headers,
      );
      
      print('📊 Response status: ${response.statusCode}');
      // print('📄 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        print('✅ API success: ${jsonResponse['success']}');
        
        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'];
          final buildings = data.map((json) => Building.fromJson(json)).toList();
          
          print('🎯 Loaded ${buildings.length} buildings');
          return buildings;
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to fetch buildings');
        }
      } else if (response.statusCode == 401) {
        // Try without token (public access)
        print('⚠️ Token invalid, trying public access...');
        
        final publicResponse = await http.get(
          Uri.parse('${AppConstants.apiBaseUrl}/buildings'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        );
        
        if (publicResponse.statusCode == 200) {
          final jsonResponse = jsonDecode(publicResponse.body);
          if (jsonResponse['success'] == true) {
            final List<dynamic> data = jsonResponse['data'];
            return data.map((json) => Building.fromJson(json)).toList();
          }
        }
        
        throw Exception('Unauthorized. Please login.');
      } else if (response.statusCode == 404) {
        throw Exception('Buildings endpoint not found (404). Check backend server.');
      } else {
        throw Exception('Failed to fetch buildings: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Building repository error: $e');
      rethrow;
    }
  }
  
  // Get building by ID
  Future<Building> getBuildingById(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('${AppConstants.apiBaseUrl}/buildings/$id'),
        headers: headers,
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          return Building.fromJson(jsonResponse['data']);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to fetch building');
        }
      } else if (response.statusCode == 404) {
        throw Exception('Building not found (404)');
      } else {
        throw Exception('Failed to fetch building: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Create building
  Future<Building> createBuilding({
    required String name,
    String? code,
    String? description,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'name': name,
        'code': code,
        'description': description,
      });
      
      print('📤 Creating building: $name');
      print('📤 Request body: $body');
      
      final response = await http.post(
        Uri.parse('${AppConstants.apiBaseUrl}/buildings'),
        headers: headers,
        body: body,
      );
      
      print('📊 Create response: ${response.statusCode}');
      print('📄 Response body: ${response.body}');
      
      if (response.statusCode == 201) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          return Building.fromJson(jsonResponse['data']);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to create building');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to create building: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Update building
  Future<Building> updateBuilding({
    required String id,
    required String name,
    String? code,
    String? description,
  }) async {
    try {
      final headers = await _getHeaders();
      final body = jsonEncode({
        'name': name,
        'code': code,
        'description': description,
      });
      
      final response = await http.put(
        Uri.parse('${AppConstants.apiBaseUrl}/buildings/$id'),
        headers: headers,
        body: body,
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          return Building.fromJson(jsonResponse['data']);
        } else {
          throw Exception(jsonResponse['message'] ?? 'Failed to update building');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to update building: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Delete building
  Future<void> deleteBuilding(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('${AppConstants.apiBaseUrl}/buildings/$id'),
        headers: headers,
      );
      
      print('🗑️ Delete building response: ${response.statusCode}');
      print('📄 Delete response body: ${response.body}');
      
      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to delete building');
      }
    } catch (e) {
      rethrow;
    }
  }
}