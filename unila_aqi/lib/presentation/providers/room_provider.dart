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

  static const String _cacheKey = 'cache_dashboard_rooms';

  // FIXED: Auto-refresh UI tiap 1 menit.
  // Backend tetap update DB tiap 10 detik — frontend hanya fetch ulang
  // dari API setiap 60 detik, bukan live socket.
  static const Duration _autoRefreshInterval = Duration(minutes: 1);

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
  // FIXED: timer baru untuk auto-refresh 60 detik.
  Timer? _autoRefreshTimer;

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

      // FIXED: Tidak subscribe ke dataStream lagi.
      // Data update lewat _autoRefreshTimer (60 detik) atau manual refresh.
      // Socket hanya untuk event struktural (room added/deleted/renamed).

      _setupSocketListeners();
      _startAutoRefreshTimer();

      _socketConnected = _socketService.isConnected;
      await _storageService.setSocketConnected(_socketConnected);

      notifyListeners();
    } catch (e) {
      print('❌ Error initializing socket: $e');
      _socketConnected = false;
    }
  }

  /// FIXED: auto-refresh baru — 1 menit sekali, fetch ulang dari API.
  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) async {
      if (_isRefreshing) return;
      print('🔄 RoomProvider auto-refresh (1 minute): fetching fresh data...');
      await _refreshData();
    });
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
    // FIXED: hanya event STRUKTURAL yang di-listen.
    // 'room-update' & 'dashboard-update' (data AQI tiap 10s) TIDAK di-listen
    // lagi — data update via _autoRefreshTimer (60s) atau manual refresh.
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

  Future<void> loadFromCache() async {
    try {
      final cached = _storageService.getJson(_cacheKey);
      if (cached != null && cached['data'] is List) {
        final list = (cached['data'] as List)
            .map((e) => Room.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (list.isNotEmpty && _rooms.isEmpty) {
          _rooms = list;
          _applyFilters();
          _lastUpdate = DateTime.now();
          notifyListeners();
        }
      }
    } catch (_) {
      // cache rusak — abaikan, biarkan loadRooms yang isi
    }
  }

  Future<void> loadRooms() async {
    // Hanya tampilkan spinner jika belum ada data (cache kosong).
    _isLoading = _rooms.isEmpty;
    _hasError = false;
    notifyListeners();

    try {
      if (!_socketConnected) {
        await initSocket();
      }

      _rooms = await _roomRepository.getRooms();
      _applyFilters();
      _lastUpdate = DateTime.now();

      // Simpan ke cache untuk cold-start berikutnya
      try {
        await _storageService.setJson(_cacheKey, {
          'data': _rooms.map((r) => r.toJson()).toList(),
        });
      } catch (_) {}
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
      print('❌ Error loading rooms: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Manual refresh — dipakai tombol refresh di Dashboard.
  /// Menampilkan spinner (`_isRefreshing = true`).
  Future<void> refresh() async {
    if (_isRefreshing) return;

    _isRefreshing = true;
    _hasError = false;
    notifyListeners();

    try {
      _rooms = await _roomRepository.getRooms();
      _applyFilters();
      _lastUpdate = DateTime.now();

      try {
        await _storageService.setJson(_cacheKey, {
          'data': _rooms.map((r) => r.toJson()).toList(),
        });
      } catch (_) {}
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  /// FIXED: silent background refresh — dipanggil oleh _autoRefreshTimer.
  /// Tidak menampilkan spinner, hanya notify kalau ada perubahan.
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

        // Cache diperbarui supaya cold-start berikutnya tampil data terbaru
        try {
          await _storageService.setJson(_cacheKey, {
            'data': _rooms.map((r) => r.toJson()).toList(),
          });
        } catch (_) {}

        print('✅ RoomProvider auto-refresh updated ${_rooms.length} rooms');
      } else {
        print('ℹ️ RoomProvider auto-refresh: no changes');
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
        result.sort((a, b) {
          final aV = a.currentAQI;
          final bV = b.currentAQI;
          if (aV == null && bV == null) return 0;
          if (aV == null) return 1; // null ditaruh di akhir
          if (bV == null) return -1;
          return aV.compareTo(bV);
        });
        break;
      case 'AQI Terburuk':
        result.sort((a, b) {
          final aV = a.currentAQI;
          final bV = b.currentAQI;
          if (aV == null && bV == null) return 0;
          if (aV == null) return 1;
          if (bV == null) return -1;
          return bV.compareTo(aV);
        });
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

  // FIXED: signature diubah ke dynamic + guard tipe.
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

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _socketSubscription?.cancel();
    _socketService.disconnect();
    _socketService.off('dashboard-room-updated');
    _socketService.off('room-deleted');
    _socketService.off('room-name-changed');
    _socketService.off('room-building-changed');
    super.dispose();
  }
}