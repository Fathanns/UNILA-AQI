import 'package:flutter/material.dart';
import '../../data/models/building.dart';
import '../../core/services/api_service.dart';

class BuildingProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<Building> _buildings = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Getters
  List<Building> get buildings => _buildings;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  
  // Load buildings - USE REAL DATA
  Future<void> loadBuildings() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      print('🔄 Loading REAL buildings from database...');
      final response = await _apiService.getBuildings();
      
      if (response['success'] == true) {
        final List<dynamic> data = response['data'];
        _buildings = data.map((json) => Building.fromJson(json)).toList();
        print('✅ Loaded ${_buildings.length} REAL buildings from database');
      } else {
        throw Exception('Failed to load buildings: ${response['message']}');
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      print('❌ Error loading REAL buildings: $e');
      
      // Fallback to test data
      try {
        print('⚠️ Trying fallback to test data...');
        final response = await _apiService.getTestBuildings();
        if (response['success'] == true) {
          final List<dynamic> data = response['data'];
          _buildings = data.map((json) => Building.fromJson(json)).toList();
          _hasError = false;
          print('⚠️ Loaded ${_buildings.length} buildings from TEST data (fallback)');
        }
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Get building by ID
  Building? getBuildingById(String buildingId) {
    try {
      return _buildings.firstWhere((building) => building.id == buildingId);
    } catch (e) {
      return null;
    }
  }
  
  // Add building
  Future<void> addBuilding({
    required String name,
    String? code,
    String? description,
  }) async {
    try {
      final response = await _apiService.createBuilding({
        'name': name,
        'code': code,
        'description': description,
      });
      
      if (response['success'] == true) {
        final building = Building.fromJson(response['data']);
        _buildings.add(building);
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Update building
  Future<void> updateBuilding({
    required String buildingId,
    required String name,
    String? code,
    String? description,
  }) async {
    try {
      final response = await _apiService.updateBuilding(buildingId, {
        'name': name,
        'code': code,
        'description': description,
      });
      
      if (response['success'] == true) {
        final updatedBuilding = Building.fromJson(response['data']);
        final index = _buildings.indexWhere((b) => b.id == buildingId);
        if (index != -1) {
          _buildings[index] = updatedBuilding;
          notifyListeners();
        }
      }
    } catch (e) {
      rethrow;
    }
  }
  
  // Delete building
  Future<void> deleteBuilding(String buildingId) async {
    try {
      await _apiService.deleteBuilding(buildingId);
      _buildings.removeWhere((building) => building.id == buildingId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }
  
  // Clear error
  void clearError() {
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
  }
}