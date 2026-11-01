import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/repositories/room_repository.dart';
import '../../../data/repositories/building_repository.dart';
import '../../../data/models/room.dart';
import '../../../data/models/building.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/constants/colors.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/services/api_service.dart';
import '../../../data/repositories/iot_device_repository.dart';
import '../../../data/models/iot_device.dart';
import '../../widgets/common/server_status_indicator.dart';

class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  final RoomRepository _roomRepository = RoomRepository();
  final BuildingRepository _buildingRepository = BuildingRepository();
  final SocketService _socketService = SocketService();
  final ApiService _apiService = ApiService();
  final StorageService _storage = StorageService();
  final TextEditingController _searchController = TextEditingController();

  static const String _cacheKey = 'cache_rooms';
  static const Duration _autoRefreshInterval = Duration(minutes: 1);

  List<Room> _rooms = [];
  List<Room> _filteredRooms = [];
  List<Building> _buildings = [];
  String _selectedBuildingFilter = 'Semua Gedung';
  bool _isLoading = false;
  bool _hasError = false;
  bool _isRefreshing = false;
  String _errorMessage = '';

  Timer? _reloadDebounce;
  Timer? _autoRefreshTimer;

  List<String> get _availableBuildings {
    final set = <String>{'Semua Gedung'};
    for (final b in _buildings) {
      final name = b.name.trim();
      if (name.isNotEmpty) set.add(name);
    }
    for (final r in _rooms) {
      final name = r.buildingName.trim();
      if (name.isNotEmpty) set.add(name);
    }
    if (set.length <= 1) return set.toList();
    final rest = set.toList().sublist(1)..sort();
    return ['Semua Gedung', ...rest];
  }

  @override
  void initState() {
    super.initState();
    _loadCacheThenFetch();
    _setupSocketListeners();
    _startAutoRefreshTimer();
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) async {
      if (_isRefreshing || !mounted) return;
      await _loadData();
    });
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) {
      try {
        return Map<String, dynamic>.from(data);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void _setupSocketListeners() {
    if (!_socketService.isConnected && !_socketService.isConnecting) {
      _socketService.connect();
    }

    _socketService.on(
        'dashboard-room-updated', _handleDashboardRoomUpdated);
    _socketService.on('room-deleted', _handleRoomDeleted);
    _socketService.on('room-name-changed', _handleRoomNameChanged);
    _socketService.on(
        'room-building-changed', _handleRoomBuildingChanged);
  }

  void _handleDashboardRoomUpdated(dynamic data) {
    if (!mounted) return;
    _scheduleReload();
  }

  void _handleRoomDeleted(dynamic data) {
    if (!mounted) return;
    final map = _asMap(data);
    if (map == null) return;
    final roomId = map['roomId']?.toString();
    if (roomId == null) return;
    setState(() {
      _rooms.removeWhere((r) => r.id == roomId);
    });
    _filterRooms();
  }

  void _handleRoomNameChanged(dynamic data) {
    if (!mounted) return;
    _scheduleReload();
  }

  void _handleRoomBuildingChanged(dynamic data) {
    if (!mounted) return;
    _scheduleReload();
  }

  void _scheduleReload() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) _loadData();
    });
  }

  @override
  void dispose() {
    _reloadDebounce?.cancel();
    _autoRefreshTimer?.cancel();
    _socketService.off('dashboard-room-updated');
    _socketService.off('room-deleted');
    _socketService.off('room-name-changed');
    _socketService.off('room-building-changed');
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCacheThenFetch() async {
    Map<String, dynamic>? cached;
    try {
      cached = _storage.getJson(_cacheKey);
    } catch (_) {
      cached = null;
    }

    if (cached != null && cached['data'] is List) {
      try {
        final list = (cached['data'] as List)
            .map((e) =>
                Room.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (mounted) {
          setState(() {
            _rooms = list;
          });
        }
      } catch (_) {}
    }

    if (cached != null && cached['buildings'] is List) {
      try {
        final bList = (cached['buildings'] as List)
            .map((e) =>
                Building.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (mounted) {
          setState(() {
            _buildings = bList;
          });
        }
      } catch (_) {}
    }

    _filterRooms();
    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = _rooms.isEmpty;
      _hasError = false;
    });

    try {
      final List<Object> results = await Future.wait([
        _roomRepository.getRooms(),
        _buildingRepository.getBuildings(),
      ]);

      final List<Room> rooms = results[0] as List<Room>;
      final List<Building> buildings = results[1] as List<Building>;

      if (!mounted) return;

      setState(() {
        _rooms = rooms;
        _buildings = buildings;
      });

      _filterRooms();

      try {
        await _storage.setJson(_cacheKey, {
          'data': rooms.map((r) => r.toJson()).toList(),
          'buildings': buildings.map((b) => b.toJson()).toList(),
        });
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;

      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
      } else {
        Helpers.showSnackBar(
          context,
          'Gagal memuat data ruangan',
          isError: true,
        );
      }

      if (_rooms.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = Helpers.friendlyErrorMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleManualRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      ServerStatusIndicator.checkNow();
      try {
        await _apiService.forceRefresh();
      } catch (_) {}
      await _loadData();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _filterRooms() {
  if (!_availableBuildings.contains(_selectedBuildingFilter)) {
    _selectedBuildingFilter = 'Semua Gedung';
  }

  List<Room> filtered = _rooms;

  if (_selectedBuildingFilter != 'Semua Gedung') {
    filtered = filtered
        .where((room) => room.buildingName == _selectedBuildingFilter)
        .toList();
  }

  if (_searchController.text.isNotEmpty) {
    final query = _searchController.text.toLowerCase();
    filtered = filtered
        .where((room) =>
            room.name.toLowerCase().contains(query) ||
            room.buildingName.toLowerCase().contains(query))
        .toList();
  }

  // ✅ URUTAN BARU: kelompokkan per gedung (alfabetis),
  // lalu di dalam gedung yang sama urutkan berdasarkan nama ruangan (alfabetis).
  filtered = List<Room>.from(filtered)
    ..sort((a, b) {
      final cmpBuilding =
          a.buildingName.toLowerCase().compareTo(b.buildingName.toLowerCase());
      if (cmpBuilding != 0) return cmpBuilding;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

  if (mounted) {
    setState(() => _filteredRooms = filtered);
  } else {
    _filteredRooms = filtered;
  }
}

  Future<void> _deleteRoom(String roomId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Ruangan'),
        content: const Text(
            'Apakah Anda yakin ingin menghapus ruangan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _roomRepository.deleteRoom(roomId);
      await _loadData();
      if (!mounted) return;
      Helpers.showSnackBar(context, 'Ruangan berhasil dihapus');
    } catch (e) {
      if (!mounted) return;
      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
      } else {
        final msg = Helpers.extractBackendMessage(
          e,
          fallback: 'Gagal menghapus ruangan. Silakan coba lagi.',
        );
        Helpers.showSnackBar(context, msg, isError: true);
      }
    }
  }

  void _navigateToAddRoom() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditRoomScreen(
          buildings: _buildings,
          onRoomSaved: _loadData,
        ),
      ),
    );
  }

  void _navigateToEditRoom(Room room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditRoomScreen(
          room: room,
          buildings: _buildings,
          onRoomSaved: _loadData,
        ),
      ),
    );
  }

  String? _getStaleDurationText(Room room) {
    final lastUpdate = room.currentData.updatedAt.toLocal();
    final diff = DateTime.now().difference(lastUpdate);

    if (diff.inMinutes <= 5) return null;
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit';
    if (diff.inHours < 24) return '${diff.inHours} jam';
    return '${diff.inDays} hari';
  }

  // ============================================================
  // WIDGETS — selaras dengan Profil Admin
  // ============================================================

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withOpacity(0.5), width: 3),
            ),
            child: const Icon(Icons.meeting_room,
                size: 44, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Kelola Ruangan',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_rooms.length} RUANGAN TERDAFTAR',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1,
                fontFamily: 'Inter',
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _navigateToAddRoom,
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text(
                'TAMBAH RUANGAN',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side:
                    const BorderSide(color: Colors.white, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Cari ruangan...',
              prefixIcon: const Icon(Icons.search,
                  size: 20, color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _filterRooms();
                      },
                    )
                  : null,
            ),
            onChanged: (value) => _filterRooms(),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBuildingFilter,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down),
                onChanged: (value) {
                  setState(() {
                    _selectedBuildingFilter = value!;
                    _filterRooms();
                  });
                },
                items: _availableBuildings.map((building) {
                  return DropdownMenuItem(
                    value: building,
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt_outlined,
                            size: 16, color: AppColors.textHint),
                        const SizedBox(width: 8),
                        Text(building),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Room room) {
    final aqiColor = Helpers.getAQIColor(room.currentAQI);
    final aqiLabel = Helpers.getAQILabel(room.currentAQI);
    final staleDuration = _getStaleDurationText(room);
    final isIot = room.dataSource == 'iot';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.meeting_room,
                    size: 24,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 11, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              room.buildingName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textHint,
                                fontFamily: 'Inter',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: aqiColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: aqiColor.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '${room.currentAQI}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: aqiColor,
                          fontFamily: 'Inter',
                        ),
                      ),
                      Text(
                        aqiLabel,
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: aqiColor,
                          fontFamily: 'Inter',
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Source badge
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isIot
                        ? Colors.blue.withOpacity(0.1)
                        : Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isIot
                            ? Icons.sensors
                            : Icons.auto_awesome,
                        size: 11,
                        color:
                            isIot ? Colors.blue : Colors.purple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isIot ? 'Device IoT' : 'Simulasi',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isIot
                              ? Colors.blue[700]
                              : Colors.purple[700],
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 12, color: AppColors.textHint),
                const SizedBox(width: 6),
                Text(
                  'Dibuat: ${Helpers.formatDateTime(room.createdAt.toLocal())}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
              ],
            ),

            // Stale warning
            if (staleDuration != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.orange.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data belum diperbarui selama $staleDuration',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: _buildCardAction(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    color: AppColors.primary,
                    onTap: () => _navigateToEditRoom(room),
                  ),
                ),
                Container(width: 1, height: 24, color: AppColors.border),
                Expanded(
                  child: _buildCardAction(
                    icon: Icons.delete_outline,
                    label: 'Hapus',
                    color: AppColors.error,
                    onTap: () => _deleteRoom(room.id),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final isNetwork = Helpers.isNetworkError(_errorMessage);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 72,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak dapat memuat data',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isNetwork
                  ? 'Tidak dapat terhubung ke server.\nPeriksa koneksi internet Anda atau coba beberapa saat lagi.'
                  : 'Terjadi kesalahan saat memuat data.\nSilakan coba lagi.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final hasSearch = _searchController.text.trim().isNotEmpty;
    final hasFilter = _selectedBuildingFilter != 'Semua Gedung';

    String message;
    if (hasSearch && hasFilter) {
      message =
          'Tidak ada ruangan yang cocok dengan\n"${_searchController.text.trim()}"\ndi $_selectedBuildingFilter';
    } else if (hasSearch) {
      message =
          'Tidak ada ruangan yang cocok dengan\n"${_searchController.text.trim()}"';
    } else if (hasFilter) {
      message = 'Tidak ada ruangan di\n"$_selectedBuildingFilter"';
    } else {
      message = 'Belum ada ruangan terdaftar';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off
                  : (hasFilter
                      ? Icons.filter_alt_off_outlined
                      : Icons.meeting_room_outlined),
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
                fontFamily: 'Inter',
              ),
            ),
            if (hasSearch || hasFilter) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _selectedBuildingFilter = 'Semua Gedung';
                  _filterRooms();
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset Filter & Pencarian'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Ruangan'),
        actions: [
          const ServerStatusIndicator(),
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    size: 22,
                    color: AppColors.textSecondary,
                  ),
            onPressed: _isRefreshing ? null : _handleManualRefresh,
            splashRadius: 20,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleManualRefresh,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _buildHeaderCard(),
            _buildSearchCard(),
            if (_isLoading && _rooms.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_hasError && _rooms.isEmpty)
              _buildErrorState()
            else if (_filteredRooms.isEmpty)
              _buildEmptyState()
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children:
                      _filteredRooms.map(_buildRoomCard).toList(),
                ),
              ),
            if (_filteredRooms.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Total: ${_filteredRooms.length} ruangan',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ADD / EDIT ROOM SCREEN (TIDAK BERUBAH)
// ============================================================
class AddEditRoomScreen extends StatefulWidget {
  final Room? room;
  final List<Building> buildings;
  final VoidCallback onRoomSaved;

  const AddEditRoomScreen({
    super.key,
    this.room,
    required this.buildings,
    required this.onRoomSaved,
  });

  bool get isEditing => room != null;

  @override
  State<AddEditRoomScreen> createState() => _AddEditRoomScreenState();
}

class _AddEditRoomScreenState extends State<AddEditRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final RoomRepository _roomRepository = RoomRepository();
  final IoTDeviceRepository _iotDeviceRepository = IoTDeviceRepository();

  String? _selectedBuildingId;
  String _selectedDataSource = 'simulation';
  String? _selectedIotDeviceId;
  bool _isLoading = false;
  List<IoTDevice> _iotDevices = [];

  @override
  void initState() {
    super.initState();

    if (widget.isEditing) {
      final room = widget.room!;
      _nameController.text = room.name;

      final buildingExists =
          widget.buildings.any((b) => b.id == room.buildingId);
      _selectedBuildingId = buildingExists
          ? room.buildingId
          : (widget.buildings.isNotEmpty
              ? widget.buildings.first.id
              : null);

      _selectedDataSource = room.dataSource;
      _selectedIotDeviceId = room.iotDeviceId;
    } else if (widget.buildings.isNotEmpty) {
      _selectedBuildingId = widget.buildings.first.id;
    }

    _loadIoTDevices();
  }

  Future<void> _loadIoTDevices() async {
    try {
      final devices = await _iotDeviceRepository.getDevices();
      if (!mounted) return;
      setState(() => _iotDevices = devices);
    } catch (e) {
      debugPrint('Error loading IoT devices: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveRoom() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBuildingId == null) {
      Helpers.showSnackBar(context, 'Pilih gedung terlebih dahulu',
          isError: true);
      return;
    }

    if (_selectedDataSource == 'iot' && _selectedIotDeviceId == null) {
      Helpers.showSnackBar(
          context, 'Pilih device IoT terlebih dahulu',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.isEditing) {
        final dataSourceChanged = _selectedDataSource !=
            (widget.room?.dataSource ?? 'simulation');
        final deviceChanged =
            _selectedIotDeviceId != widget.room?.iotDeviceId;

        await _roomRepository.updateRoom(
          id: widget.room!.id,
          name: _nameController.text.trim(),
          buildingId: _selectedBuildingId!,
          dataSource: _selectedDataSource,
          iotDeviceId:
              _selectedDataSource == 'iot' ? _selectedIotDeviceId : null,
        );

        if (!mounted) return;

        widget.onRoomSaved();

        final String message;
        if (_selectedDataSource == 'iot' &&
            (dataSourceChanged || deviceChanged)) {
          message =
              'Ruangan diperbarui. Data partikel device baru sedang dimuat…';
        } else {
          message = 'Ruangan berhasil diperbarui';
        }
        Helpers.showSnackBar(context, message);
      } else {
        await _roomRepository.createRoom(
          name: _nameController.text.trim(),
          buildingId: _selectedBuildingId!,
          dataSource: _selectedDataSource,
          iotDeviceId:
              _selectedDataSource == 'iot' ? _selectedIotDeviceId : null,
        );
        if (!mounted) return;
        Helpers.showSnackBar(context, 'Ruangan berhasil ditambahkan');

        widget.onRoomSaved();
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
      } else {
        final msg = Helpers.extractBackendMessage(
          e,
          fallback: 'Gagal menyimpan ruangan. Silakan coba lagi.',
        );
        Helpers.showSnackBar(context, msg, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.isEditing ? 'Edit Ruangan' : 'Tambah Ruangan'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nama Ruangan*',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Contoh: H17, Lab Komputer, Ruang Baca',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama ruangan wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Gedung*',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBuildingId,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    hint: const Text('Pilih Gedung'),
                    onChanged: (value) {
                      setState(() => _selectedBuildingId = value);
                    },
                    items: widget.buildings.map((building) {
                      return DropdownMenuItem(
                        value: building.id,
                        child: Text(building.displayName),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Sumber Data',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Radio(
                      value: 'simulation',
                      groupValue: _selectedDataSource,
                      onChanged: (value) {
                        setState(() => _selectedDataSource = value!);
                      },
                    ),
                    title: const Text('Simulasi'),
                    subtitle: const Text('Data acak setiap 10 detik'),
                    dense: true,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Radio(
                      value: 'iot',
                      groupValue: _selectedDataSource,
                      onChanged: (value) {
                        setState(() => _selectedDataSource = value!);
                      },
                    ),
                    title: const Text('Device IoT'),
                    subtitle: const Text('Data dari sensor fisik'),
                    dense: true,
                  ),
                  if (_selectedDataSource == 'iot')
                    Padding(
                      padding: const EdgeInsets.only(left: 40, top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Pilih Device IoT:',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedIotDeviceId,
                                isExpanded: true,
                                icon:
                                    const Icon(Icons.arrow_drop_down),
                                hint: const Text('Pilih Device IoT'),
                                onChanged: (value) {
                                  setState(() =>
                                      _selectedIotDeviceId = value);
                                },
                                items: _iotDevices.map((device) {
                                  return DropdownMenuItem(
                                    value: device.id,
                                    child: Text(device.name),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          if (_selectedIotDeviceId == null)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Device IoT wajib dipilih untuk sumber data IoT',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.red),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveRoom,
                  child: Text(
                    widget.isEditing
                        ? 'SIMPAN PERUBAHAN'
                        : 'SIMPAN RUANGAN',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}