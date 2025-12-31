import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import '../../../data/models/room.dart';
import '../../../presentation/providers/room_provider.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../presentation/widgets/common/drawer.dart';
import '../../../presentation/widgets/common/building_section.dart';
import '../../../presentation/pages/room/room_detail_screen.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/constants/colors.dart';

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
  final RefreshController _refreshController = RefreshController();
  final TextEditingController _searchController = TextEditingController();
  
  Timer? _autoRefreshTimer;
  int _autoRefreshCountdown = 10;
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    
    // Delay initialization to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted) {
        _loadInitialData();
        _startAutoRefresh();
      }
    });
  }
  
  @override
  void dispose() {
    _isMounted = false;
    _refreshController.dispose();
    _searchController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }
  
 Future<void> _loadInitialData() async {
  if (!_isMounted) return;
  
  final roomProvider = Provider.of<RoomProvider>(context, listen: false);
  
  try {
    await roomProvider.loadRooms();
  } catch (e) {
    print('❌ Error loading rooms: $e');
    
    // Tampilkan pesan error yang user-friendly
    if (e.toString().contains('401') || e.toString().contains('Access denied')) {
      Helpers.showSnackBar(
        context, 
        'Tidak bisa mengakses data. Silakan login sebagai admin atau hubungi administrator.',
        isError: true
      );
    }
  }
}
  
  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isMounted) {
        timer.cancel();
        return;
      }
      
      // Use WidgetsBinding to schedule after build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_isMounted) return;
        
        setState(() {
          if (_autoRefreshCountdown <= 0) {
            _autoRefreshCountdown = 10;
            _refreshData();
          } else {
            _autoRefreshCountdown--;
          }
        });
      });
    });
  }
  
  Future<void> _refreshData() async {
    if (!_isMounted) return;
    
    final roomProvider = Provider.of<RoomProvider>(context, listen: false);
    await roomProvider.refresh();
    
    if (_isMounted) {
      _refreshController.refreshCompleted();
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
  
  void _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    
    // Navigate back to mode selection
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/',
      (route) => false,
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshData,
            tooltip: 'Refresh',
          ),
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
              tooltip: 'Menu',
            ),
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
          Helpers.showSnackBar(context, 'Profile management coming soon!');
        },
        onLogoutTap: _handleLogout,
      ),
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _refreshData,
        header: const WaterDropHeader(
          waterDropColor: AppColors.primary,
        ),
        child: CustomScrollView(
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
            // Loading State
            if (roomProvider.isLoading)
              const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            // Error State
            else if (roomProvider.hasError)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: AppColors.error,
                      ),
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
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
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
            // Data State - Grouped by Building
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final buildingEntries = roomProvider.roomsByBuilding.entries.toList();
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
            // Auto Refresh Indicator
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Auto refresh: ${_autoRefreshCountdown}s',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildBuildingDropdown(RoomProvider roomProvider) {
    // Remove duplicates from building list
    final uniqueBuildings = roomProvider.buildings.toSet().toList();
    
    // Log for debugging
    if (uniqueBuildings.length != roomProvider.buildings.length) {
      print('⚠️ Removed duplicate buildings. Original: ${roomProvider.buildings.length}, Unique: ${uniqueBuildings.length}');
      print('Duplicates: ${roomProvider.buildings.where((building) => roomProvider.buildings.where((b) => b == building).length > 1).toSet()}');
    }
    
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: roomProvider.selectedBuilding,
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
            child: Text(
              building,
              overflow: TextOverflow.ellipsis,
            ),
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