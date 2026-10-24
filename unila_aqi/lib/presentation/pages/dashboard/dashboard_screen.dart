import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:unila_aqi/core/services/socket_service.dart';
import '../../../data/models/room.dart';
import '../../../presentation/providers/room_provider.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/widgets/common/drawer.dart';
import '../../../presentation/widgets/common/building_section.dart';
import '../../../presentation/pages/room/room_detail_screen.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/constants/colors.dart';
import '../../pages/info/aqi_info_screen.dart';
import '../../../presentation/widgets/common/server_status_indicator.dart';

class DashboardScreen extends StatefulWidget {
  final bool isAdminMode;

  const DashboardScreen({
    super.key,
    this.isAdminMode = false,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  // Timer? _autoRefreshTimer;
  // int _autoRefreshCountdown = 10;
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;

    // Delay initialization to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted) {
        _loadInitialData();
        // _startAutoRefresh();
        _setupBuildingUpdateListener();
        _setupRoomNameUpdateListener(); // 🔥 BARU: Tambah listener untuk update nama ruangan
      }
    });
  }

  // 🔥 BARU: Setup listener untuk update nama ruangan
  // FIXED: guard data agar tidak TypeError saat payload rusak.
  void _setupRoomNameUpdateListener() {
    Provider.of<RoomProvider>(context, listen: false);
    final socketService = SocketService();

    // Listen for room name updates
    socketService.on('room-name-changed', (data) {
      if (!_isMounted) return;
      final map = _asMap(data);
      if (map == null) return;

      final oldName = map['oldName']?.toString() ?? '-';
      final newName = map['newName']?.toString() ?? '-';

      print('🔄 Room name update received: $oldName -> $newName');

      // Refresh data untuk update tampilan
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isMounted) {
          _refreshData();

          // Show notification
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Nama ruangan diperbarui: $oldName -> $newName'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      });
    });

    // Listen for dashboard-room-updated events
    // FIXED: guard data + nested access.
    socketService.on('dashboard-room-updated', (data) {
      if (!_isMounted) return;
      final map = _asMap(data);
      if (map == null) return;
      if (map['action'] != 'updated') return;

      print('📡 Dashboard room update received');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_isMounted) {
          _refreshData();
        }
      });
    });
  }

  // FIXED: guard data agar tidak TypeError saat payload rusak.
  void _setupBuildingUpdateListener() {
    Provider.of<RoomProvider>(context, listen: false);
    final socketService = SocketService();

    // Listen for building updates
    socketService.on('building-updated', (data) {
      if (!_isMounted) return;
      final map = _asMap(data);
      if (map == null) return;

      print('🏢 Building update received: ${map['action']}');

      // Jika building diedit, refresh data
      if (map['action'] == 'updated') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_isMounted) {
            _refreshData();

            // Show notification
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Data gedung diperbarui'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
      }
    });
  }

  // FIXED: helper untuk memvalidasi payload socket.
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

  @override
  void dispose() {
    _isMounted = false;
    _searchController.dispose();
    // _autoRefreshTimer?.cancel();

    // Remove event listeners
    final socketService = SocketService();
    socketService.off('building-updated');
    socketService.off('room-name-changed'); // 🔥 BARU: Hapus listener nama ruangan
    socketService.off('dashboard-room-updated'); // 🔥 BARU: Hapus listener dashboard

    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!_isMounted) return;

    final roomProvider = Provider.of<RoomProvider>(context, listen: false);

    try {
      await roomProvider.loadRooms();
    } catch (e) {
      if (!_isMounted) return;
      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
      } else if (e.toString().contains('401') ||
          e.toString().contains('Access denied')) {
        Helpers.showSnackBar(
          context,
          'Tidak bisa mengakses data. Silakan login sebagai admin atau hubungi administrator.',
          isError: true,
        );
      } else {
        Helpers.showSnackBar(
          context,
          'Gagal memuat data: $e',
          isError: true,
        );
      }
    }

    // Setelah load, cek apakah provider menyimpan error (loadRooms catch internal)
    if (_isMounted && roomProvider.hasError && roomProvider.rooms.isEmpty) {
      final msg = roomProvider.errorMessage.toLowerCase();
      if (msg.contains('socketexception') ||
          msg.contains('network') ||
          msg.contains('connection') ||
          msg.contains('timeout') ||
          msg.contains('failed host')) {
        Helpers.showServerError(context);
      }
    }
  }

  Future<void> _refreshData() async {
    if (!_isMounted) return;

    final roomProvider = Provider.of<RoomProvider>(context, listen: false);

    try {
      await roomProvider.refresh();
    } catch (e) {
      if (_isMounted) {
        if (Helpers.isNetworkError(e)) {
          Helpers.showServerError(context);
        } else {
          Helpers.showSnackBar(context, 'Gagal refresh: $e', isError: true);
        }
      }
    }

    // Cek provider error juga (refresh menangkap internal)
    if (_isMounted && roomProvider.hasError) {
      final msg = roomProvider.errorMessage.toLowerCase();
      final isNet = msg.contains('socketexception') ||
          msg.contains('network') ||
          msg.contains('connection') ||
          msg.contains('timeout') ||
          msg.contains('failed host');
      if (isNet) {
        Helpers.showServerError(context);
      }
    }
  }

  void _handleRoomTap(Room room) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoomDetailScreen(room: room),
      ),
    );
  }

  // FIXED: sebelumnya tidak ada try-catch → unhandled exception saat server
  // mati. Sekarang: error di-log, navigasi tetap dijalankan di `finally`.
  void _handleLogout() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
    } catch (e) {
      debugPrint('❌ Logout error: $e');
    } finally {
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',
          (route) => false,
        );
      }
    }
  }

  void _handleHelpTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AQIInfoScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roomProvider = Provider.of<RoomProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('UNILA Air Quality Index'),
        centerTitle: true,
        actions: [
          const ServerStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ServerStatusIndicator.checkNow();
              _refreshData();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: AppDrawer(
        isAdmin: widget.isAdminMode,
        onDashboardTap: () => Navigator.pop(context),
        onBuildingsTap: () {
          Navigator.pushNamed(context, '/admin/buildings');
        },
        onRoomsTap: () {
          Navigator.pushNamed(context, '/admin/rooms');
        },
        onDevicesTap: () {
          Navigator.pushNamed(context, '/admin/iot-devices');
        },
        onProfileTap: () {
          Navigator.pushNamed(context, '/admin/profile');
        },
        onHelpTap: _handleHelpTap,
        onLogoutTap: _handleLogout,
      ),
      body: CustomScrollView(
        slivers: [
          // Search and Filter Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Search Bar
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: '🔍 Search...',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                roomProvider.updateSearchQuery('');
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      roomProvider.updateSearchQuery(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  // Filter Row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: _buildBuildingDropdown(roomProvider),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: _buildSortDropdown(roomProvider),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Loading State — hanya jika belum ada data
          if (roomProvider.isLoading && roomProvider.rooms.isEmpty)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          // Error State — hanya jika TIDAK ada data sama sekali
          else if (roomProvider.hasError && roomProvider.rooms.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${roomProvider.errorMessage}',
                      style: const TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshData,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          // Empty State
          else if (roomProvider.rooms.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.search_off,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Tidak ada ruangan ditemukan',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    if (_searchController.text.isNotEmpty ||
                        roomProvider.selectedBuilding != 'Semua Gedung')
                      TextButton(
                        onPressed: () {
                          roomProvider.clearFilters();
                          _searchController.clear();
                        },
                        child: const Text('Reset Filter'),
                      ),
                  ],
                ),
              ),
            )
          // Data State — tetap tampil walau refresh error
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final buildingEntries =
                      roomProvider.roomsByBuilding.entries.toList();
                  final buildingName = buildingEntries[index].key;
                  final rooms = buildingEntries[index].value;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: BuildingSection(
                      buildingName: buildingName,
                      rooms: rooms,
                      onRoomTap: _handleRoomTap,
                    ),
                  );
                },
                childCount: roomProvider.roomsByBuilding.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBuildingDropdown(RoomProvider roomProvider) {
    // Remove duplicates from building list
    final uniqueBuildings = roomProvider.buildings.toSet().toList();

    // ✅ Pastikan value selalu ada di items
    String selectedValue = roomProvider.selectedBuilding;
    if (!uniqueBuildings.contains(selectedValue)) {
      selectedValue = 'Semua Gedung';

      // Sinkronkan juga ke provider agar konsisten
      WidgetsBinding.instance.addPostFrameCallback((_) {
        roomProvider.updateBuildingFilter('Semua Gedung');
      });
    }

    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: selectedValue, // ✅ gunakan selectedValue
        isExpanded: true,
        icon: const Icon(Icons.arrow_drop_down),
        onChanged: (value) {
          if (value != null) {
            roomProvider.updateBuildingFilter(value);
          }
        },
        items: uniqueBuildings.map((building) {
          return DropdownMenuItem(
            value: building,
            child: Text(building, overflow: TextOverflow.ellipsis),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSortDropdown(RoomProvider roomProvider) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: roomProvider.sortBy,
        isExpanded: true,
        icon: const Icon(Icons.arrow_drop_down),
        onChanged: (value) {
          if (value != null) {
            roomProvider.updateSort(value);
          }
        },
        items: const [
          DropdownMenuItem(
            value: 'Terbaru',
            child: Text('Terbaru'),
          ),
          DropdownMenuItem(
            value: 'A-Z',
            child: Text('A-Z'),
          ),
          DropdownMenuItem(
            value: 'AQI Terbaik',
            child: Text('AQI Terbaik'),
          ),
          DropdownMenuItem(
            value: 'AQI Terburuk',
            child: Text('AQI Terburuk'),
          ),
        ],
      ),
    );
  }
}