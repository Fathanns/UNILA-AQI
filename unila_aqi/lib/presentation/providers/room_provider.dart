import 'dart:async';
import 'package:flutter/material.dart';
import 'package:unila_aqi/data/repositories/room_repository.dart';
import 'package:unila_aqi/core/services/socket_service.dart';
import 'package:unila_aqi/core/services/storage_service.dart';
import '../../data/models/room.dart';
 
class RoomProvider with ChangeNotifier {
  final RoomRepository _roomRepository = RoomRepository();
  final SocketService _socketService = SocketService();
  final StorageService _storageService = StorageService();
 
  List<Room> _rooms = [];
  List<Room> _filteredRooms = [];
  String _selectedBuilding = 'Semua Gedung';
  String _sortBy = 'Terbaru';
  String _searchQuery = '';
 
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _socketConnected = false;
  bool _isRefreshing = false;
 
  // Timer for periodic refresh
  // Timer? _refreshTimer;
  // final Duration _refreshInterval = Duration(seconds: 60); // Refresh every 60 seconds
  DateTime _lastUpdate = DateTime.now();
 
  // Stream subscriptions
  StreamSubscription? _socketSubscription;
  StreamSubscription? _dataSubscription;
 
  // Getters
  List<Room> get rooms => _filteredRooms;
  List<Room> get allRooms => _rooms;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  String get selectedBuilding => _selectedBuilding;
  String get sortBy => _sortBy;
  String get searchQuery => _searchQuery;
  bool get socketConnected => _socketConnected;
  DateTime get lastUpdate => _lastUpdate;
 
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
 
  // Initialize socket connection and start periodic refresh
  Future<void> initSocket() async {
  try {
    // Get auth token
    final token = await _storageService.getString('auth_token');
    
    // Connect to WebSocket
    await _socketService.connect(token: token);
    
    // Setup connection listener
    _socketSubscription = _socketService.connectionStream.listen((connected) {
      _socketConnected = connected;
      notifyListeners();
    });
    
    // Setup data listener
    _dataSubscription = _socketService.dataStream.listen(_handleSocketData);
    
    // Setup listeners
    _setupSocketListeners();
    
    // Update status
    _socketConnected = _socketService.isConnected;
    await _storageService.setSocketConnected(_socketConnected);
    
    if (_socketConnected) {
      print('✅ Socket.io initialized and connected');
    }
    
    notifyListeners();
  } catch (e) {
    print('❌ Error initializing socket: $e');
    _socketConnected = false;
  }
}

void _setupSocketListeners() {
  _socketService.on('room-update', _handleRoomUpdate);
  _socketService.on('dashboard-update', _handleDashboardUpdate);
  _socketService.on('room-name-changed', (data) {
    handleRoomNameChanged(data);
  });
  _socketService.on('room-building-changed', (data) {
    handleBuildingNameChanged(data);
  });
}
 
  // Start periodic refresh timer
  // void _startPeriodicRefresh() {
  //   if (_refreshTimer != null && _refreshTimer!.isActive) {
  //     _refreshTimer!.cancel();
  //   }
 
  //   _refreshTimer = Timer.periodic(_refreshInterval, (timer) {
  //     if (_socketConnected) {
  //       // Use socket for real-time updates
  //       _socketService.requestRefresh();
  //     } else {
  //       // Fallback to API refresh
  //       _refreshData();
  //     }
  //   });
 
  //   print('🔄 Started periodic refresh every ${_refreshInterval.inSeconds}s');
  // }
 
  // Stop periodic refresh timer
  // void _stopPeriodicRefresh() {
  //   if (_refreshTimer != null) {
  //     _refreshTimer!.cancel();
  //     _refreshTimer = null;
  //     print('⏹️ Stopped periodic refresh');
  //   }
  // }
 
  // Handle socket data stream
  void _handleSocketData(Map<String, dynamic> data) {
    final type = data['type'];
    final payload = data['data'];
 
    switch (type) {
      case 'room-update':
        _handleRoomUpdate(payload);
        break;
      case 'dashboard-update':
        _handleDashboardUpdate(payload);
        break;
    }
  }
 
  // Handle room update from WebSocket
  void _handleRoomUpdate(dynamic data) {
  try {
    final roomId = data['roomId'];
    final roomData = data['data'];
    final source = data['source'] ?? 'unknown';
    final action = data['action']; // 🔥 BARU: Tambah handling untuk action

    print('🔄 Processing ${source.toUpperCase()} update for room: $roomId (action: ${action})');

    // Jika ada action 'updated' dan ada oldData, cek apakah nama berubah
    if (action == 'updated' && data['oldData'] != null) {
      final oldData = data['oldData'];
      final newName = roomData['name'];
      final oldName = oldData['name'];
      
      if (newName != oldName) {
        print('🔄 Detected name change in update: $oldName -> $newName');
        // Panggil handleRoomNameChanged untuk update nama
        handleRoomNameChanged({
          'roomId': roomId,
          'newName': newName,
          'oldName': oldName,
          'buildingName': roomData['buildingName']
        });
        return; // Keluar karena sudah dihandle oleh handleRoomNameChanged
      }
    }

    // Find room index
    final roomIndex = _rooms.indexWhere((room) => room.id == roomId);

    if (roomIndex != -1) {
      // Create updated room data
      final updatedRoom = Room(
        id: _rooms[roomIndex].id,
        name: roomData['name'] ?? _rooms[roomIndex].name, // 🔥 BARU: Ambil nama dari data baru
        buildingId: _rooms[roomIndex].buildingId,
        buildingName: roomData['buildingName'] ?? _rooms[roomIndex].buildingName, // 🔥 BARU: Ambil buildingName dari data baru
        dataSource: _rooms[roomIndex].dataSource,
        iotDeviceId: _rooms[roomIndex].iotDeviceId,
        isActive: _rooms[roomIndex].isActive,
        currentAQI: roomData['currentAQI'],
        currentData: RoomData(
          pm25: roomData['currentData']['pm25'].toDouble(),
          pm10: roomData['currentData']['pm10'].toDouble(),
          co2: roomData['currentData']['co2'].toDouble(),
          temperature: roomData['currentData']['temperature'].toDouble(),
          humidity: roomData['currentData']['humidity'].toDouble(),
          updatedAt: DateTime.parse(roomData['currentData']['updatedAt']),
        ),
        createdAt: _rooms[roomIndex].createdAt,
        updatedAt: DateTime.parse(roomData['updatedAt']),
      );

      // Update room in list
      _rooms[roomIndex] = updatedRoom;

      // Update last update time
      _lastUpdate = DateTime.now();

      // Reapply filters
      _applyFilters();

      // Notify listeners
      notifyListeners();

      print('✅ Room ${_rooms[roomIndex].name} updated via ${source.toUpperCase()}: AQI ${updatedRoom.currentAQI}');
    }
  } catch (e) {
    print('❌ Error handling room update: $e');
  }
}
 
  // Handle dashboard update
  void _handleDashboardUpdate(dynamic data) {
  try {
    final type = data['type'];
    
    switch (type) {
      case 'room-data-updated':
        // Trigger a refresh of all data
        _refreshData();
        break;
      
      case 'building-name-changed':
        // Handle building name change
        handleBuildingNameChanged(data);
        break;
        
      case 'room-name-changed':
        // 🔥 BARU: Handle room name change
        handleRoomNameChanged(data);
        break;
        
      default:
        print('ℹ️ Unknown dashboard update type: $type');
    }
  } catch (e) {
    print('❌ Error handling dashboard update: $e');
  }
}



// 🔥 BARU: Handle room name change
void handleRoomNameChanged(Map<String, dynamic> data) {
  try {
    final roomId = data['roomId'];
    final newName = data['newName'];
    final oldName = data['oldName'];
    final buildingName = data['buildingName'];
    
    print('🔄 Processing room name change: $oldName -> $newName ($roomId)');
    
    // Cari room di list
    final roomIndex = _rooms.indexWhere((room) => room.id == roomId);
    
    if (roomIndex != -1) {
      // Update room dengan nama baru
      final updatedRoom = Room(
        id: _rooms[roomIndex].id,
        name: newName, // Update nama room
        buildingId: _rooms[roomIndex].buildingId,
        buildingName: buildingName,
        dataSource: _rooms[roomIndex].dataSource,
        iotDeviceId: _rooms[roomIndex].iotDeviceId,
        isActive: _rooms[roomIndex].isActive,
        currentAQI: _rooms[roomIndex].currentAQI,
        currentData: _rooms[roomIndex].currentData,
        createdAt: _rooms[roomIndex].createdAt,
        updatedAt: DateTime.now(),
      );
      
      _rooms[roomIndex] = updatedRoom;
      
      // Reapply filters
      _applyFilters();
      
      // Update last update time
      _lastUpdate = DateTime.now();
      
      // Notify listeners
      notifyListeners();
      
      print('✅ Room name updated: $oldName -> $newName');
    } else {
      print('⚠️ Room not found in local list: $roomId');
      // Jika room tidak ditemukan, refresh data
      _refreshData();
    }
  } catch (e) {
    print('❌ Error handling room name change: $e');
  }
}
 
  // Join room for real-time updates
  void joinRoom(String roomId) {
    _socketService.joinRoom(roomId);
    _storageService.addSubscribedRoom(roomId);
  }
 
  // Leave room
  void leaveRoom(String roomId) {
    _socketService.leaveRoom(roomId);
    _storageService.removeSubscribedRoom(roomId);
  }
 
  // Check socket connection
  Future<void> checkSocketConnection() async {
    final isConnected = await _socketService.checkConnection();
    _socketConnected = isConnected;
    await _storageService.setSocketConnected(isConnected);
    notifyListeners();
  }
 
  // Reconnect socket
  Future<void> reconnectSocket() async {
    await initSocket();
  }
 
  // Initialize and load rooms
  Future<void> loadRooms() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();
 
    try {
      print('🔄 Loading rooms from database...');
 
      // Initialize socket on first load
      if (!_socketConnected) {
        await initSocket();
      }
 
      _rooms = await _roomRepository.getRooms();
      _applyFilters();
 
      print('✅ Loaded ${_rooms.length} rooms from database');
 
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      print('❌ Error loading rooms: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
 
  // Refresh data with loading indicator
  Future<void> refresh() async {
    if (_isRefreshing) return;
 
    _isRefreshing = true;
    _hasError = false;
    notifyListeners();
 
    try {
      print('🔄 Manual refresh initiated');
 
      // Force refresh from API
      _rooms = await _roomRepository.getRooms();
      _applyFilters();
 
      // Update last update time
      _lastUpdate = DateTime.now();
 
      print('✅ Manual refresh completed: ${_rooms.length} rooms');
 
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      print('❌ Error during refresh: $e');
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }
 
  // Internal refresh without loading indicator (for periodic updates)
  Future<void> _refreshData() async {
    try {
      print('🔄 Background refresh initiated');
 
      final newRooms = await _roomRepository.getRooms();
 
      // Check if data has actually changed
      bool hasChanges = false;
      if (newRooms.length != _rooms.length) {
        hasChanges = true;
      } else {
        for (int i = 0; i < newRooms.length; i++) {
          if (newRooms[i].currentAQI != _rooms[i].currentAQI ||
              newRooms[i].updatedAt != _rooms[i].updatedAt) {
            hasChanges = true;
            break;
          }
        }
      }
 
      if (hasChanges) {
        _rooms = newRooms;
        _applyFilters();
        _lastUpdate = DateTime.now();
 
        print('✅ Background refresh completed with changes');
        notifyListeners();
      } else {
        print('ℹ️ Background refresh: no changes detected');
      }
 
    } catch (e) {
      print('❌ Error during background refresh: $e');
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

  void handleBuildingNameChanged(Map<String, dynamic> data) {
  try {
    final buildingId = data['buildingId'];
    final newBuildingName = data['newBuildingName'];
    final affectedRooms = List<String>.from(data['affectedRooms'] ?? []);
    
    print('🔄 Processing building name change: $buildingId -> $newBuildingName');
    print('📋 Affected rooms: $affectedRooms');
    
    // Update all rooms that belong to this building
    bool hasChanges = false;
    for (int i = 0; i < _rooms.length; i++) {
      if (_rooms[i].buildingId == buildingId) {
        // Create updated room
        final updatedRoom = Room(
          id: _rooms[i].id,
          name: _rooms[i].name,
          buildingId: _rooms[i].buildingId,
          buildingName: newBuildingName, // Update building name
          dataSource: _rooms[i].dataSource,
          iotDeviceId: _rooms[i].iotDeviceId,
          isActive: _rooms[i].isActive,
          currentAQI: _rooms[i].currentAQI,
          currentData: _rooms[i].currentData,
          createdAt: _rooms[i].createdAt,
          updatedAt: DateTime.now(),
        );
        
        _rooms[i] = updatedRoom;
        hasChanges = true;
        
        print('✅ Updated room ${_rooms[i].name}: building name -> $newBuildingName');
      }
    }
    
    if (hasChanges) {
      // Reapply filters
      _applyFilters();
      
      // Update last update time
      _lastUpdate = DateTime.now();
      
      // Notify listeners
      notifyListeners();
      
      print('🎯 Building name update completed. Affected rooms updated.');
    }
  } catch (e) {
    print('❌ Error handling building name change: $e');
  }
}
 
  // Dispose
  @override
  void dispose() {
    // Stop refresh timer
    // _stopPeriodicRefresh();
 
    // Cancel subscriptions
    _socketSubscription?.cancel();
    _dataSubscription?.cancel();
 
    // Disconnect socket
    _socketService.disconnect();
 
    // Remove event listeners
    _socketService.off('room-update');
    _socketService.off('dashboard-update');
 
    super.dispose();
  }
}