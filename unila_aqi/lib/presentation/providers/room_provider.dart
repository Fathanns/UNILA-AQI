import 'dart:async';
import 'package:flutter/material.dart';
import 'package:unila_aqi/data/repositories/room_repository.dart';
import 'package:unila_aqi/core/services/socket_service.dart';
import 'package:unila_aqi/core/services/storage_service.dart';
import '../../data/models/room.dart';
import '../../data/models/room_realtime.dart';

class RoomProvider with ChangeNotifier {
  final RoomRepository _roomRepository = RoomRepository();
  final SocketService _socketService = SocketService();
  final StorageService _storageService = StorageService();

  static const String _cacheKey = 'cache_dashboard_rooms';

  // Debounce untuk reload penuh saat ada perubahan struktur ruangan.
  // Ini dipicu oleh event, bukan timer periodik.
  static const Duration _reloadDebounce = Duration(milliseconds: 1200);

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
  bool _wasDisconnected = false;

  DateTime _lastUpdate = DateTime.now();

  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<Map<String, dynamic>>? _dataSubscription;
  Timer? _reloadTimer;

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

  // ============================================================
  // SOCKET — dengarkan event realtime dari backend
  // ============================================================
  Future<void> initSocket() async {
    try {
      final token = await _storageService.getString('auth_token');
      await _socketService.connect(token: token);

      // Subscription dibuat sekali; pemanggilan ulang tidak menduplikasi listener.
      _connectionSubscription ??=
          _socketService.connectionStream.listen(_onConnectionChanged);
      _dataSubscription ??=
          _socketService.dataStream.listen(_onRealtimeEvent);

      _socketConnected = _socketService.isConnected;
      await _storageService.setSocketConnected(_socketConnected);

      notifyListeners();
    } catch (e) {
      print('❌ Error initializing socket: $e');
      _socketConnected = false;
    }
  }

  void _onConnectionChanged(bool connected) {
    _socketConnected = connected;

    if (!connected) {
      _wasDisconnected = true;
    } else if (_wasDisconnected) {
      // Koneksi pulih: sinkronkan sekali untuk mengambil event yang terlewat.
      _wasDisconnected = false;
      _scheduleReload();
    }

    notifyListeners();
  }

  void _onRealtimeEvent(Map<String, dynamic> event) {
    final raw = event['data'];
    if (raw is! Map) return;
    final data = Map<String, dynamic>.from(raw);

    switch (event['type']) {
      case 'dashboard-update':
        // Perubahan data sensor (IoT) — update in-place.
        _applyTelemetry(data);
        break;
      case 'dashboard-room-updated':
        // Ruangan dibuat / diubah (nama, gedung, device) — upsert snapshot.
        _applyRoomSnapshot(data);
        break;
      case 'room-deleted':
        final id = RoomRealtime.roomIdOf(data);
        if (id == null) return;
        _rooms.removeWhere((room) => room.id == id);
        _commitChange();
        break;
    }
  }

  /// Update data sensor ruangan. Tidak ada request ke server bila snapshot
  /// sudah dikirim backend.
  void _applyTelemetry(Map<String, dynamic> data) {
    final id = RoomRealtime.roomIdOf(data);
    if (id == null) return;

    final snap = RoomRealtime.snapshotOf(data);
    if (snap == null) {
      _scheduleReload();
      return;
    }

    final idx = _rooms.indexWhere((r) => r.id == id);
    if (idx == -1) {
      // Ruangan belum ada di daftar lokal — ambil daftar terbaru.
      _scheduleReload();
      return;
    }

    _rooms[idx] = RoomRealtime.merge(_rooms[idx], snap);
    _commitChange();
  }

  void _applyRoomSnapshot(Map<String, dynamic> data) {
    final snap = RoomRealtime.snapshotOf(data);
    final id = RoomRealtime.roomIdOf(data);
    if (snap == null || id == null) {
      _scheduleReload();
      return;
    }

    final idx = _rooms.indexWhere((r) => r.id == id);
    if (idx == -1) {
      _rooms.add(RoomRealtime.merge(null, snap));
    } else {
      _rooms[idx] = RoomRealtime.merge(_rooms[idx], snap);
    }
    _commitChange();
  }

  void _commitChange() {
    _applyFilters();
    _lastUpdate = DateTime.now();
    notifyListeners();
  }

  /// Reload penuh, digabung (debounce) agar beberapa event beruntun
  /// hanya memicu satu request.
  void _scheduleReload() {
    _reloadTimer?.cancel();
    _reloadTimer = Timer(_reloadDebounce, () => _refreshSilently());
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

  /// Reload senyap — dipanggil saat ada perubahan struktur atau koneksi pulih.
  /// Tidak menampilkan spinner, hanya notify bila ada perubahan.
  Future<void> _refreshSilently() async {
    try {
      final newRooms = await _roomRepository.getRooms();

      bool hasChanges = false;
      if (newRooms.length != _rooms.length) {
        hasChanges = true;
      } else {
        for (int i = 0; i < newRooms.length; i++) {
          if (newRooms[i].id != _rooms[i].id ||
              newRooms[i].name != _rooms[i].name ||
              newRooms[i].buildingName != _rooms[i].buildingName ||
              newRooms[i].currentAQI != _rooms[i].currentAQI ||
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

        try {
          await _storageService.setJson(_cacheKey, {
            'data': _rooms.map((r) => r.toJson()).toList(),
          });
        } catch (_) {}

        print('✅ RoomProvider sync updated ${_rooms.length} rooms');
      }
    } catch (e) {
      print('❌ Error during silent refresh: $e');
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

  @override
  void dispose() {
    _reloadTimer?.cancel();
    _connectionSubscription?.cancel();
    _dataSubscription?.cancel();
    _socketService.disconnect();
    super.dispose();
  }
}