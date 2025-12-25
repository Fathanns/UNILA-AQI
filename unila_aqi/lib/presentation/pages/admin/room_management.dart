import 'package:flutter/material.dart';
import '../../../data/repositories/room_repository.dart';
import '../../../data/repositories/building_repository.dart';
import '../../../data/models/room.dart';
import '../../../data/models/building.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/constants/colors.dart';
import '../../../data/repositories/iot_device_repository.dart';
import '../../../data/models/iot_device.dart';

class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  final RoomRepository _roomRepository = RoomRepository();
  final BuildingRepository _buildingRepository = BuildingRepository();
  final TextEditingController _searchController = TextEditingController();
  
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
    _loadData();
  }
  
  Future<void> _loadData() async {
  setState(() {
    _isLoading = true;
    _hasError = false;
  });
  
  try {
    final List<Object> results = await Future.wait([
      _roomRepository.getRooms(),
      _buildingRepository.getBuildings(),
    ]);
    
    // Cast hasil ke tipe yang sesuai
    final List<Room> rooms = results[0] as List<Room>;
    final List<Building> buildings = results[1] as List<Building>;
    
    setState(() {
      _rooms = rooms;
      _filteredRooms = rooms;
      _buildings = buildings;
    });
  } catch (e) {
    setState(() {
      _hasError = true;
      _errorMessage = e.toString();
    });
    Helpers.showSnackBar(context, 'Gagal memuat data ruangan: $e', isError: true);
  } finally {
    setState(() => _isLoading = false);
  }
}
  
  void _filterRooms() {
    List<Room> filtered = _rooms;
    
    // Filter by building
    if (_selectedBuildingFilter != 'Semua Gedung') {
      filtered = filtered.where((room) => 
        room.buildingName == _selectedBuildingFilter
      ).toList();
    }
    
    // Filter by search query
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((room) =>
        room.name.toLowerCase().contains(query) ||
        room.buildingName.toLowerCase().contains(query)
      ).toList();
    }
    
    setState(() => _filteredRooms = filtered);
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
            child: const Text('Hapus', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      await _roomRepository.deleteRoom(roomId);
      await _loadData();
      Helpers.showSnackBar(context, 'Ruangan berhasil dihapus');
    } catch (e) {
      Helpers.showSnackBar(context, 'Gagal menghapus ruangan: $e', isError: true);
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
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Ruangan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
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
          
          // Add Button
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
          
          // Loading State
          if (_isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          
          // Error State
          else if (_hasError)
            Expanded(
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
                      'Error: $_errorMessage',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          
          // Empty State
          else if (_filteredRooms.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.meeting_room_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tidak ada ruangan ditemukan',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_searchController.text.isNotEmpty || _selectedBuildingFilter != 'Semua Gedung')
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
          
          // Data State
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
          
          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Total: ${_filteredRooms.length} ruangan',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRoomCard(Room room) {
    final aqiColor = Helpers.getAQIColor(room.currentAQI);
    final timeAgo = Helpers.formatTimeAgo(room.currentData.updatedAt);
    
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
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: room.isActive ? Colors.green : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            room.isActive ? '● Aktif' : '○ Tidak Aktif',
                            style: TextStyle(
                              color: room.isActive ? Colors.green : Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Sumber: ${room.dataSource == 'iot' ? 'Device IoT' : 'Simulasi'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
            
            const SizedBox(height: 12),
            
            // Last Update
            Text(
              'Update: $timeAgo',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            
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
  bool _isActive = true;
  bool _isLoading = false;
  List<IoTDevice> _iotDevices = [];
  
  @override
  void initState() {
    super.initState();
    
    // Prefill fields if editing
    if (widget.isEditing) {
      final room = widget.room!;
      _nameController.text = room.name;
      _selectedBuildingId = room.buildingId;
      _selectedDataSource = room.dataSource;
      _selectedIotDeviceId = room.iotDeviceId;
      _isActive = room.isActive;
    } else if (widget.buildings.isNotEmpty) {
      // Default to first building
      _selectedBuildingId = widget.buildings.first.id;
    }
    
    // Load IoT devices
    _loadIoTDevices();
  }
  
  Future<void> _loadIoTDevices() async {
    try {
      final devices = await _iotDeviceRepository.getDevices();
      setState(() => _iotDevices = devices);
    } catch (e) {
      print('Error loading IoT devices: $e');
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
      Helpers.showSnackBar(context, 'Pilih gedung terlebih dahulu', isError: true);
      return;
    }
    
    // Validasi khusus untuk IoT data source
    if (_selectedDataSource == 'iot' && _selectedIotDeviceId == null) {
      Helpers.showSnackBar(context, 'Pilih device IoT terlebih dahulu', isError: true);
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
          iotDeviceId: _selectedDataSource == 'iot' ? _selectedIotDeviceId : null,
          isActive: _isActive,
        );
        Helpers.showSnackBar(context, 'Ruangan berhasil diperbarui');
      } else {
        await _roomRepository.createRoom(
          name: _nameController.text.trim(),
          buildingId: _selectedBuildingId!,
          dataSource: _selectedDataSource,
          iotDeviceId: _selectedDataSource == 'iot' ? _selectedIotDeviceId : null,
          isActive: _isActive,
        );
        Helpers.showSnackBar(context, 'Ruangan berhasil ditambahkan');
      }
      
      widget.onRoomSaved();
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      Helpers.showSnackBar(context, 'Gagal menyimpan ruangan: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              const Text(
                'Nama Ruangan*',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
              
              const Text(
                'Gedung*',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
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
              
              const Text(
                'Sumber Data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Column(
                children: [
                  // Simulation Option
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
                  
                  // IoT Option
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
                  
                  // IoT Device Selection (only show if IoT is selected)
                  if (_selectedDataSource == 'iot')
                    Padding(
                      padding: const EdgeInsets.only(left: 40, top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pilih Device IoT:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
                                value: _selectedIotDeviceId,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down),
                                hint: const Text('Pilih Device IoT'),
                                onChanged: (value) {
                                  setState(() => _selectedIotDeviceId = value);
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
                          if (_selectedDataSource == 'iot' && _selectedIotDeviceId == null)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'Device IoT wajib dipilih untuk sumber data IoT',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Status
              Row(
                children: [
                  const Text(
                    'Status: ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  ChoiceChip(
                    label: const Text('Aktif'),
                    selected: _isActive,
                    onSelected: (selected) {
                      setState(() => _isActive = true);
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Tidak Aktif'),
                    selected: !_isActive,
                    onSelected: (selected) {
                      setState(() => _isActive = false);
                    },
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
                    widget.isEditing ? 'SIMPAN PERUBAHAN' : 'SIMPAN RUANGAN',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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