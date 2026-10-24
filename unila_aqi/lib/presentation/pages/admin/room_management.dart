import 'package:flutter/material.dart';
import '../../../data/repositories/room_repository.dart';
import '../../../data/repositories/building_repository.dart';
import '../../../data/models/room.dart';
import '../../../data/models/building.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/constants/colors.dart';
import '../../../core/services/storage_service.dart';
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
  final StorageService _storage = StorageService();
  final TextEditingController _searchController = TextEditingController();

  static const String _cacheKey = 'cache_rooms';

  List<Room> _rooms = [];
  List<Room> _filteredRooms = [];
  List<Building> _buildings = [];
  String _selectedBuildingFilter = 'Semua Gedung';
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCacheThenFetch();
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
            .map((e) => Room.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (mounted) {
          setState(() {
            _rooms = list;
          });
          _filterRooms();
        }
      } catch (_) {}
    }

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

  void _filterRooms() {
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
        content: const Text('Apakah Anda yakin ingin menghapus ruangan ini?'),
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
        Helpers.showSnackBar(
          context,
          'Gagal menghapus ruangan',
          isError: true,
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Ruangan'),
        actions: [
          // FIXED: indikator status server ditambahkan di sini.
          const ServerStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // FIXED: picu health check paralel agar indikator langsung
              // update ke hijau/merah begitu tombol ditekan.
              ServerStatusIndicator.checkNow();
              _loadData();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '🔍 Cari ruangan...',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _filterRooms();
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) => _filterRooms(),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
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
                      items: [
                        'Semua Gedung',
                        ..._buildings.map((b) => b.name).toSet(),
                      ].map((building) {
                        return DropdownMenuItem(
                          value: building,
                          child: Text(building),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToAddRoom,
                icon: const Icon(Icons.add),
                label: const Text('TAMBAH RUANGAN'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading && _rooms.isEmpty)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_hasError && _rooms.isEmpty)
            Expanded(
              child: Center(
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
                        _errorMessage,
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
              ),
            )
          else if (_filteredRooms.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.meeting_room_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Tidak ada ruangan ditemukan',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    if (_searchController.text.isNotEmpty ||
                        _selectedBuildingFilter != 'Semua Gedung')
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          _selectedBuildingFilter = 'Semua Gedung';
                          _filterRooms();
                        },
                        child: const Text('Reset Filter'),
                      ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredRooms.length,
                itemBuilder: (context, index) {
                  final room = _filteredRooms[index];
                  return _buildRoomCard(room);
                },
              ),
            ),

          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Total: ${_filteredRooms.length} ruangan',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Room room) {
    final aqiColor = Helpers.getAQIColor(room.currentAQI);
    final staleDuration = _getStaleDurationText(room);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${room.name} - ${room.buildingName}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sumber: ${room.dataSource == 'iot' ? 'Device IoT' : 'Simulasi'}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: aqiColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: aqiColor),
                  ),
                  child: Text(
                    'AQI: ${room.currentAQI}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: aqiColor,
                    ),
                  ),
                ),
              ],
            ),
            if (staleDuration != null) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.orange.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ruangan ini belum memperbarui data selama $staleDuration',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToEditRoom(room),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _deleteRoom(room.id),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text('Hapus'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
          : (widget.buildings.isNotEmpty ? widget.buildings.first.id : null);

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
      Helpers.showSnackBar(context, 'Pilih device IoT terlebih dahulu',
          isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.isEditing) {
        await _roomRepository.updateRoom(
          id: widget.room!.id,
          name: _nameController.text.trim(),
          buildingId: _selectedBuildingId!,
          dataSource: _selectedDataSource,
          iotDeviceId:
              _selectedDataSource == 'iot' ? _selectedIotDeviceId : null,
        );
        if (!mounted) return;
        Helpers.showSnackBar(context, 'Ruangan berhasil diperbarui');
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
      }

      widget.onRoomSaved();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
      } else {
        Helpers.showSnackBar(
          context,
          'Gagal menyimpan ruangan',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Ruangan' : 'Tambah Ruangan'),
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
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
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
                    subtitle: const Text('Data acak setiap 1 menit'),
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
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: Colors.grey.shade300),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedIotDeviceId,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down),
                                hint: const Text('Pilih Device IoT'),
                                onChanged: (value) {
                                  setState(
                                      () => _selectedIotDeviceId = value);
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