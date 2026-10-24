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

  DateTime _lastUpdate = DateTime.now();

  StreamSubscription? _socketSubscription;
  StreamSubscription? _dataSubscription;

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

  List<String> get buildings {
    final buildingSet = <String>{'Semua Gedung'};
    for (final room in _rooms) {
      if (room.buildingName.isNotEmpty) {
        buildingSet.add(room.buildingName);
      }
    }
    return buildingSet.toList();
  }

  Future<void> initSocket() async {
    try {
      final token = await _storageService.getString('auth_token');
      await _socketService.connect(token: token);

      _socketSubscription = _socketService.connectionStream.listen((connected) {
        _socketConnected = connected;
        notifyListeners();
      });

      _dataSubscription = _socketService.dataStream.listen(_handleSocketData);

      _setupSocketListeners();

      _socketConnected = _socketService.isConnected;
      await _storageService.setSocketConnected(_socketConnected);

      notifyListeners();
    } catch (e) {
      print('❌ Error initializing socket: $e');
      _socketConnected = false;
    }
  }

  // FIXED: guard tipe data agar payload null/rusak tidak memicu TypeError.
  void _handleRoomDeleted(dynamic data) {
    if (data is! Map) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final roomId = map['roomId'];
      final roomName = map['roomName'];

      print('🗑️ Processing room deletion: $roomName ($roomId)');

      final initialLength = _rooms.length;
      _rooms.removeWhere((room) => room.id == roomId);

      if (_rooms.length < initialLength) {
        _lastUpdate = DateTime.now();
        _applyFilters();
        notifyListeners();
        print('✅ Room removed from dashboard: $roomName');
      }
    } catch (e) {
      print('❌ Error handling room deletion: $e');
    }
  }

  // FIXED: guard tipe data agar payload null/rusak tidak memicu TypeError.
  void _handleDashboardRoomUpdated(dynamic data) {
    if (data is! Map) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final action = map['action'];
      final roomData = map['room'];

      if (action != 'created' || roomData == null || roomData is! Map) return;

      final roomMap = Map<String, dynamic>.from(roomData);
      final roomId = roomMap['id']?.toString();
      if (roomId == null) return;

      if (_rooms.any((r) => r.id == roomId)) {
        print('ℹ️ Room already exists in list, skipping: $roomId');
        return;
      }

      final newRoom = Room(
        id: roomId,
        name: roomMap['name']?.toString() ?? 'Unknown',
        buildingId: roomMap['buildingId']?.toString() ?? '',
        buildingName: roomMap['buildingName']?.toString() ?? 'Unknown',
        dataSource: roomMap['dataSource']?.toString() ?? 'simulation',
        iotDeviceId: roomMap['iotDeviceId']?.toString(),
        currentAQI: (roomMap['currentAQI'] as num?)?.toInt() ?? 0,
        currentData: RoomData.fromJson(
          roomMap['currentData'] is Map
              ? Map<String, dynamic>.from(roomMap['currentData'])
              : <String, dynamic>{},
        ),
        createdAt: roomMap['createdAt'] != null
            ? DateTime.parse(roomMap['createdAt'].toString())
            : DateTime.now(),
        updatedAt: roomMap['updatedAt'] != null
            ? DateTime.parse(roomMap['updatedAt'].toString())
            : DateTime.now(),
      );

      _rooms.add(newRoom);
      _lastUpdate = DateTime.now();
      _applyFilters();
      notifyListeners();

      print('✅ Room added to dashboard: ${newRoom.name} (${newRoom.buildingName})');
    } catch (e) {
      print('❌ Error handling dashboard-room-updated: $e');
    }
  }

  void _setupSocketListeners() {
    _socketService.on('room-update', _handleRoomUpdate);
    _socketService.on('dashboard-update', _handleDashboardUpdate);
    _socketService.on('dashboard-room-updated', _handleDashboardRoomUpdated);
    _socketService.on('room-name-changed', (data) {
      handleRoomNameChanged(data);
    });
    _socketService.on('room-building-changed', (data) {
      handleBuildingNameChanged(data);
    });
    _socketService.on('room-deleted', _handleRoomDeleted);
  }

  void _validateSelectedBuilding() {
    final availableBuildings = buildings;
    if (!availableBuildings.contains(_selectedBuilding)) {
      _selectedBuilding = 'Semua Gedung';
    }
  }

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
      case 'room-deleted':
        _handleRoomDeleted(payload);
        break;
      case 'dashboard-room-updated':
        _handleDashboardRoomUpdated(payload);
        break;
    }
  }

  // FIXED: guard tipe data + akses field via map lokal agar konsisten.
  void _handleRoomUpdate(dynamic data) {
    if (data is! Map) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final roomId = map['roomId'];
      final roomData = map['data'];
      final source = map['source'] ?? 'unknown';
      final action = map['action'];

      print('🔄 Processing ${source.toString().toUpperCase()} update for room: $roomId (action: $action)');

      if (roomData is! Map) return;
      final roomMap = Map<String, dynamic>.from(roomData);

      if (action == 'updated' && map['oldData'] != null && map['oldData'] is Map) {
        final oldMap = Map<String, dynamic>.from(map['oldData']);
        final newName = roomMap['name'];
        final oldName = oldMap['name'];

        if (newName != oldName) {
          handleRoomNameChanged({
            'roomId': roomId,
            'newName': newName,
            'oldName': oldName,
            'buildingName': roomMap['buildingName']
          });
          return;
        }
      }

      final roomIndex = _rooms.indexWhere((room) => room.id == roomId);

      if (roomIndex != -1) {
        final currentRoomData = roomMap['currentData'];
        if (currentRoomData is! Map) return;

        final cdMap = Map<String, dynamic>.from(currentRoomData);

        final updatedRoom = Room(
          id: _rooms[roomIndex].id,
          name: roomMap['name'] ?? _rooms[roomIndex].name,
          buildingId: _rooms[roomIndex].buildingId,
          buildingName: roomMap['buildingName'] ?? _rooms[roomIndex].buildingName,
          dataSource: _rooms[roomIndex].dataSource,
          iotDeviceId: _rooms[roomIndex].iotDeviceId,
          currentAQI: (roomMap['currentAQI'] as num?)?.toInt() ??
              _rooms[roomIndex].currentAQI,
          currentData: RoomData(
            pm25: (cdMap['pm25'] as num?)?.toDouble() ?? 0,
            pm10: (cdMap['pm10'] as num?)?.toDouble() ?? 0,
            co2: (cdMap['co2'] as num?)?.toDouble() ?? 0,
            temperature: (cdMap['temperature'] as num?)?.toDouble() ?? 0,
            humidity: (cdMap['humidity'] as num?)?.toDouble() ?? 0,
            updatedAt: cdMap['updatedAt'] != null
                ? DateTime.parse(cdMap['updatedAt'].toString())
                : DateTime.now(),
          ),
          createdAt: _rooms[roomIndex].createdAt,
          updatedAt: roomMap['updatedAt'] != null
              ? DateTime.parse(roomMap['updatedAt'].toString())
              : DateTime.now(),
        );

        _rooms[roomIndex] = updatedRoom;
        _lastUpdate = DateTime.now();
        _applyFilters();
        notifyListeners();

        print('✅ Room ${_rooms[roomIndex].name} updated via ${source.toString().toUpperCase()}: AQI ${updatedRoom.currentAQI}');
      }
    } catch (e) {
      print('❌ Error handling room update: $e');
    }
  }

  // FIXED: guard tipe data + delegasi yang aman ke handler lain.
  void _handleDashboardUpdate(dynamic data) {
    if (data is! Map) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final type = map['type'];

      switch (type) {
        case 'room-data-updated':
          _refreshData();
          break;
        case 'building-name-changed':
          handleBuildingNameChanged(map);
          break;
        case 'room-name-changed':
          handleRoomNameChanged(map);
          break;
        default:
          print('ℹ️ Unknown dashboard update type: $type');
      }
    } catch (e) {
      print('❌ Error handling dashboard update: $e');
    }
  }

  // FIXED: signature diubah dari Map<String,dynamic> ke dynamic + guard,
  // agar tidak mismatch tipe saat dipanggil dari callback socket.
  void handleRoomNameChanged(dynamic data) {
    if (data is! Map) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final roomId = map['roomId'];
      final newName = map['newName'];
      final oldName = map['oldName'];
      final buildingName = map['buildingName'];

      print('🔄 Processing room name change: $oldName -> $newName ($roomId)');

      final roomIndex = _rooms.indexWhere((room) => room.id == roomId);

      if (roomIndex != -1) {
        final updatedRoom = Room(
          id: _rooms[roomIndex].id,
          name: newName ?? _rooms[roomIndex].name,
          buildingId: _rooms[roomIndex].buildingId,
          buildingName: buildingName ?? _rooms[roomIndex].buildingName,
          dataSource: _rooms[roomIndex].dataSource,
          iotDeviceId: _rooms[roomIndex].iotDeviceId,
          currentAQI: _rooms[roomIndex].currentAQI,
          currentData: _rooms[roomIndex].currentData,
          createdAt: _rooms[roomIndex].createdAt,
          updatedAt: DateTime.now(),
        );

        _rooms[roomIndex] = updatedRoom;
        _applyFilters();
        _lastUpdate = DateTime.now();
        notifyListeners();

        print('✅ Room name updated: $oldName -> $newName');
      } else {
        print('⚠️ Room not found in local list: $roomId');
        _refreshData();
      }
    } catch (e) {
      print('❌ Error handling room name change: $e');
    }
  }

  void joinRoom(String roomId) {
    _socketService.joinRoom(roomId);
    _storageService.addSubscribedRoom(roomId);
  }

  void leaveRoom(String roomId) {
    _socketService.leaveRoom(roomId);
    _storageService.removeSubscribedRoom(roomId);
  }

  Future<void> checkSocketConnection() async {
    final isConnected = await _socketService.checkConnection();
    _socketConnected = isConnected;
    await _storageService.setSocketConnected(isConnected);
    notifyListeners();
  }

  Future<void> reconnectSocket() async {
    await initSocket();
  }

  Future<void> loadRooms() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      if (!_socketConnected) {
        await initSocket();
      }

      _rooms = await _roomRepository.getRooms();
      _applyFilters();
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      print('❌ Error loading rooms: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _hasError = false;
    notifyListeners();

    try {
      _rooms = await _roomRepository.getRooms();
      _applyFilters();
      _lastUpdate = DateTime.now();
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> _refreshData() async {
    try {
      final newRooms = await _roomRepository.getRooms();

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
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error during background refresh: $e');
    }
  }

  void _applyFilters() {
    _validateSelectedBuilding();

    List<Room> result = List.from(_rooms);

    if (_selectedBuilding != 'Semua Gedung') {
      result = result.where((room) => room.buildingName == _selectedBuilding).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      result = result.where((room) =>
        room.name.toLowerCase().contains(query) ||
        room.buildingName.toLowerCase().contains(query)
      ).toList();
    }

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

  void clearFilters() {
    _selectedBuilding = 'Semua Gedung';
    _sortBy = 'Terbaru';
    _searchQuery = '';
    _applyFilters();
    notifyListeners();
  }

  Room? getRoomById(String roomId) {
    try {
      return _rooms.firstWhere((room) => room.id == roomId);
    } catch (e) {
      return null;
    }
  }

  // FIXED: signature diubah ke dynamic + guard tipe.
  void handleBuildingNameChanged(dynamic data) {
    if (data is! Map) return;
    try {
      final map = Map<String, dynamic>.from(data);
      final buildingId = map['buildingId'];
      final newBuildingName = map['newBuildingName'];

      print('🔄 Processing building name change: $buildingId -> $newBuildingName');

      bool hasChanges = false;
      for (int i = 0; i < _rooms.length; i++) {
        if (_rooms[i].buildingId == buildingId) {
          final updatedRoom = Room(
            id: _rooms[i].id,
            name: _rooms[i].name,
            buildingId: _rooms[i].buildingId,
            buildingName: newBuildingName ?? _rooms[i].buildingName,
            dataSource: _rooms[i].dataSource,
            iotDeviceId: _rooms[i].iotDeviceId,
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
        _applyFilters();
        _lastUpdate = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      print('❌ Error handling building name change: $e');
    }
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _dataSubscription?.cancel();
    _socketService.disconnect();
    _socketService.off('room-update');
    _socketService.off('dashboard-update');
    _socketService.off('dashboard-room-updated');
    _socketService.off('room-deleted');
    super.dispose();
  }
}