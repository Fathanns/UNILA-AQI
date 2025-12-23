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
  
  // Load buildings
  Future<void> loadBuildings() async {
  _isLoading = true;
  _hasError = false;
  notifyListeners();

  try {
    final response = await _apiService.getTestBuildings();
    
    if (response['success'] == true) {
      final List<dynamic> data = response['data'];
      _buildings = data.map((json) => Building.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load buildings: ${response['message']}');
    }
  } catch (e) {
    _hasError = true;
    _errorMessage = e.toString();
    print('Error loading buildings: $e');
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
  
  // Add building (will be implemented in Phase 2)
  Future<void> addBuilding({
    required String name,
    String? code,
    String? description,
  }) async {
    // TODO: Implement in Phase 2
    notifyListeners();
  }
  
  // Update building (will be implemented in Phase 2)
  Future<void> updateBuilding({
    required String buildingId,
    required String name,
    String? code,
    String? description,
  }) async {
    // TODO: Implement in Phase 2
    notifyListeners();
  }
  
  // Delete building (will be implemented in Phase 2)
  Future<void> deleteBuilding(String buildingId) async {
    // TODO: Implement in Phase 2
    notifyListeners();
  }
  
  // Clear error
  void clearError() {
    _hasError = false;
    _errorMessage = '';
    notifyListeners();
  }
}