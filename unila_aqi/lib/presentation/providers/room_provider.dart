import 'package:flutter/material.dart';
import 'package:unila_aqi/data/repositories/room_repository.dart';
import '../../data/models/room.dart';
import '../../core/services/api_service.dart';

class RoomProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final RoomRepository _roomRepository = RoomRepository();
  
  List<Room> _rooms = [];
  List<Room> _filteredRooms = [];
  String _selectedBuilding = 'Semua Gedung';
  String _sortBy = 'Terbaru';
  String _searchQuery = '';
  
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  
  // Getters
  List<Room> get rooms => _filteredRooms;
  List<Room> get allRooms => _rooms;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  String get selectedBuilding => _selectedBuilding;
  String get sortBy => _sortBy;
  String get searchQuery => _searchQuery;
  
  // Get unique buildings for filter
  List<String> get buildings {
    final buildingSet = <String>{'Semua Gedung'};
    
    for (final room in _rooms) {
      if (room.buildingName.isNotEmpty) {
        buildingSet.add(room.buildingName);
      }
    }
    
    return buildingSet.toList();
  }
  
  // Initialize and load rooms - USE REAL DATA
  Future<void> loadRooms() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      print('🔄 Loading REAL rooms from database...');
      
      // OPTION 1: Use RoomRepository (recommended)
      _rooms = await _roomRepository.getRooms();
      
      // OPTION 2: Use ApiService directly
      // final response = await _apiService.getRooms();
      // if (response['success'] == true) {
      //   final List<dynamic> data = response['data'];
      //   _rooms = data.map((json) => Room.fromJson(json)).toList();
      // }
      
      _applyFilters();
      
      print('✅ Loaded ${_rooms.length} REAL rooms from database');
      
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      print('❌ Error loading REAL rooms: $e');
      
      // Fallback to test data only as last resort
      try {
        print('⚠️ Trying fallback to test data...');
        final response = await _apiService.getTestRooms();
        if (response['success'] == true) {
          final List<dynamic> data = response['data'];
          _rooms = data.map((json) => Room.fromJson(json)).toList();
          _applyFilters();
          _hasError = false;
          print('⚠️ Loaded ${_rooms.length} rooms from TEST data (fallback)');
        }
      } catch (fallbackError) {
        print('❌ Fallback also failed: $fallbackError');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Apply all filters and sorting
  void _applyFilters() {
    // Start with all rooms
    List<Room> result = List.from(_rooms);
    
    // Apply building filter
    if (_selectedBuilding != 'Semua Gedung') {
      result = result.where((room) => room.buildingName == _selectedBuilding).toList();
    }
    
    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((room) =>
        room.name.toLowerCase().contains(query) ||
        room.buildingName.toLowerCase().contains(query)
      ).toList();
    }
    
    // Apply sorting
    switch (_sortBy) {
      case 'Terbaru':
        result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case 'A-Z':
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'AQI Terbaik':
        result.sort((a, b) => a.currentAQI.compareTo(b.currentAQI));
        break;
      case 'AQI Terburuk':
        result.sort((a, b) => b.currentAQI.compareTo(a.currentAQI));
        break;
    }
    
    _filteredRooms = result;
  }
  
  // Update filters
  void updateBuildingFilter(String building) {
    _selectedBuilding = building;
    _applyFilters();
    notifyListeners();
  }
  
  void updateSort(String sortBy) {
    _sortBy = sortBy;
    _applyFilters();
    notifyListeners();
  }
  
  void updateSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }
  
  // Get rooms by building
  Map<String, List<Room>> get roomsByBuilding {
    final Map<String, List<Room>> result = {};
    
    for (final room in _filteredRooms) {
      final buildingName = room.buildingName;
      if (!result.containsKey(buildingName)) {
        result[buildingName] = [];
      }
      result[buildingName]!.add(room);
    }
    
    return result;
  }
  
  // Refresh data
  Future<void> refresh() async {
    await loadRooms();
  }
  
  // Clear filters
  void clearFilters() {
    _selectedBuilding = 'Semua Gedung';
    _sortBy = 'Terbaru';
    _searchQuery = '';
    _applyFilters();
    notifyListeners();
  }
  
  // Get room by ID
  Room? getRoomById(String roomId) {
    try {
      return _rooms.firstWhere((room) => room.id == roomId);
    } catch (e) {
      return null;
    }
  }
 
}

extension RoomCopyWith on Room {
  Room copyWith({
    String? id,
    String? name,
    String? buildingId,
    String? buildingName,
    String? dataSource,
    String? iotDeviceId,
    bool? isActive,
    int? currentAQI,
    RoomData? currentData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      buildingId: buildingId ?? this.buildingId,
      buildingName: buildingName ?? this.buildingName,
      dataSource: dataSource ?? this.dataSource,
      iotDeviceId: iotDeviceId ?? this.iotDeviceId,
      isActive: isActive ?? this.isActive,
      currentAQI: currentAQI ?? this.currentAQI,
      currentData: currentData ?? this.currentData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}