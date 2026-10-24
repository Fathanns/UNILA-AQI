import 'package:flutter/material.dart';
import '../../../data/repositories/iot_device_repository.dart';
import '../../../data/models/iot_device.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/constants/colors.dart';
import '../../../core/services/storage_service.dart';
import '../../widgets/common/server_status_indicator.dart';

class IoTManagementScreen extends StatefulWidget {
  const IoTManagementScreen({super.key});

  @override
  State<IoTManagementScreen> createState() => _IoTManagementScreenState();
}

class _IoTManagementScreenState extends State<IoTManagementScreen> {
  final IoTDeviceRepository _deviceRepository = IoTDeviceRepository();
  final StorageService _storage = StorageService();
  final TextEditingController _searchController = TextEditingController();

  static const String _cacheKey = 'cache_iot_devices';

  List<IoTDevice> _devices = [];
  List<IoTDevice> _filteredDevices = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCacheThenFetch();
  }

  Future<void> _loadCacheThenFetch() async {
    try {
      final cached = _storage.getJson(_cacheKey);
      if (cached != null && cached['data'] is List) {
        final list = (cached['data'] as List)
            .map((e) =>
                IoTDevice.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (mounted) {
          setState(() {
            _devices = list;
            _filteredDevices = list;
          });
        }
      }
    } catch (_) {}

    await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = _devices.isEmpty;
      _hasError = false;
    });

    try {
      final devices = await _deviceRepository.getDevices();
      if (!mounted) return;

      setState(() {
        _devices = devices;
        _filteredDevices = devices;
      });

      try {
        await _storage.setJson(_cacheKey, {
          'data': devices.map((d) => d.toJson()).toList(),
        });
      } catch (_) {}
        } catch (e) {
      if (!mounted) return;

      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
      } else {
        Helpers.showSnackBar(
          context,
          'Gagal memuat data device',
          isError: true,
        );
      }

      if (_devices.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = Helpers.friendlyErrorMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterDevices(String query) {
    if (query.isEmpty) {
      setState(() => _filteredDevices = _devices);
    } else {
      final filtered = _devices.where((device) {
        final name = device.name.toLowerCase();
        final description = device.description?.toLowerCase() ?? '';
        final search = query.toLowerCase();
        return name.contains(search) || description.contains(search);
      }).toList();
      setState(() => _filteredDevices = filtered);
    }
  }

  Future<void> _deleteDevice(String deviceId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Device IoT'),
        content:
            const Text('Apakah Anda yakin ingin menghapus device ini?'),
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
      await _deviceRepository.deleteDevice(deviceId);
      await _loadData();
      if (mounted) {
        Helpers.showSnackBar(context, 'Device berhasil dihapus');
      }
    } catch (e) {
      if (!mounted) return;
      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
      } else {
        Helpers.showSnackBar(
          context,
          'Gagal menghapus device: $e',
          isError: true,
        );
      }
    }
  }

  void _navigateToAddDevice() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditIoTDeviceScreen(
          onDeviceSaved: _loadData,
        ),
      ),
    );
  }

  void _navigateToEditDevice(IoTDevice device) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditIoTDeviceScreen(
          device: device,
          onDeviceSaved: _loadData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Device IoT'),
        actions: [
          const ServerStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
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
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '🔍 Cari device...',
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
                          _filterDevices('');
                        },
                      )
                    : null,
              ),
              onChanged: _filterDevices,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToAddDevice,
                icon: const Icon(Icons.add),
                label: const Text('TAMBAH DEVICE'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading && _filteredDevices.isEmpty)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
                    else if (_hasError && _filteredDevices.isEmpty)
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
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge,
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
          else if (_filteredDevices.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sensors_off,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text('Tidak ada device ditemukan',
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey)),
                    const SizedBox(height: 8),
                    if (_searchController.text.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          _filterDevices('');
                        },
                        child: const Text('Reset Pencarian'),
                      ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredDevices.length,
                itemBuilder: (context, index) {
                  final device = _filteredDevices[index];
                  return _buildDeviceCard(device);
                },
              ),
            ),

          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Total: ${_filteredDevices.length} device',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard(IoTDevice device) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              device.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (device.description != null &&
                device.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  device.description!,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.grey),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Endpoint: ${device.apiEndpoint}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToEditDevice(device),
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
                    onPressed: () => _deleteDevice(device.id),
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

class AddEditIoTDeviceScreen extends StatefulWidget {
  final IoTDevice? device;
  final VoidCallback onDeviceSaved;

  const AddEditIoTDeviceScreen({
    super.key,
    this.device,
    required this.onDeviceSaved,
  });

  bool get isEditing => device != null;

  @override
  State<AddEditIoTDeviceScreen> createState() =>
      _AddEditIoTDeviceScreenState();
}

class _AddEditIoTDeviceScreenState extends State<AddEditIoTDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _endpointController = TextEditingController();
  final IoTDeviceRepository _deviceRepository = IoTDeviceRepository();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.isEditing) {
      final device = widget.device!;
      _nameController.text = device.name;
      _descriptionController.text = device.description ?? '';
      _endpointController.text = device.apiEndpoint;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _endpointController.dispose();
    super.dispose();
  }

  Future<void> _saveDevice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.isEditing) {
        await _deviceRepository.updateDevice(
          id: widget.device!.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          apiEndpoint: _endpointController.text.trim(),
        );
        if (mounted) {
          Helpers.showSnackBar(context, 'Device berhasil diperbarui');
        }
      } else {
        await _deviceRepository.createDevice(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          apiEndpoint: _endpointController.text.trim(),
        );
        if (mounted) {
          Helpers.showSnackBar(context, 'Device berhasil ditambahkan');
        }
      }

      widget.onDeviceSaved();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
      } else {
        Helpers.showSnackBar(
          context,
          'Gagal menyimpan device: $e',
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
        title: Text(
            widget.isEditing ? 'Edit Device IoT' : 'Tambah Device IoT'),
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
              const Text('Nama Device*',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Device 1 - Gedung H',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama device wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Deskripsi',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  hintText: 'Deskripsi device (opsional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              const Text('Endpoint API*',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _endpointController,
                decoration: const InputDecoration(
                  hintText: 'https://example.com/api/sensor-data',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Endpoint API wajib diisi';
                  }
                  try {
                    Uri.parse(value);
                  } catch (e) {
                    return 'Format URL tidak valid';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveDevice,
                  child: Text(
                    widget.isEditing
                        ? 'SIMPAN PERUBAHAN'
                        : 'SIMPAN DEVICE',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
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