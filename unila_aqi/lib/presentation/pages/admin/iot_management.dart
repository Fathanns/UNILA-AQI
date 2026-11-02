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
  bool _isRefreshing = false;
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
      final devices = await _deviceRepository.getDevices(live: true);
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

  Future<void> _handleManualRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await _loadData();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
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
        final msg = Helpers.extractBackendMessage(
          e,
          fallback: 'Gagal menghapus perangkat. Silakan coba lagi.',
        );
        Helpers.showSnackBar(context, msg, isError: true);
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
            child: const Icon(Icons.sensors,
                size: 44, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Kelola Device IoT',
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
              '${_devices.length} DEVICE TERDAFTAR',
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
              onPressed: _navigateToAddDevice,
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text(
                'TAMBAH DEVICE',
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

  Widget _buildSummarySection() {
    final onlineCount = _devices.where((d) => d.isOnline).length;
    final offlineCount = _devices.length - onlineCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.sensors,
              label: 'Total',
              value: '${_devices.length}',
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.cloud_done,
              label: 'Online',
              value: '$onlineCount',
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.cloud_off,
              label: 'Offline',
              value: '$offlineCount',
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
                fontFamily: 'Inter',
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
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
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cari device...',
          prefixIcon: const Icon(Icons.search,
              size: 20, color: AppColors.textHint),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _filterDevices('');
                  },
                )
              : null,
        ),
        onChanged: _filterDevices,
      ),
    );
  }

  Widget _buildDeviceCard(IoTDevice device) {
    final isOnline = device.isOnline;
    final statusColor = isOnline ? AppColors.success : AppColors.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    Icons.sensors,
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
                        device.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Inter',
                        ),
                      ),
                      if (device.description != null &&
                          device.description!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          device.description!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: statusColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link,
                      size: 14, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      device.apiEndpoint,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            if (device.lastUpdate != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.update,
                      size: 12, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(
                    'Update terakhir: ${Helpers.formatLastUpdateWithDate(device.lastUpdate!)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textHint,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
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
                    onTap: () => _navigateToEditDevice(device),
                  ),
                ),
                Container(width: 1, height: 24, color: AppColors.border),
                Expanded(
                  child: _buildCardAction(
                    icon: Icons.delete_outline,
                    label: 'Hapus',
                    color: AppColors.error,
                    onTap: () => _deleteDevice(device.id),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch ? Icons.search_off : Icons.sensors_off,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Tidak ada device yang cocok dengan\n"${_searchController.text.trim()}"'
                  : 'Belum ada device terdaftar',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
                fontFamily: 'Inter',
              ),
            ),
            if (hasSearch) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  _filterDevices('');
                },
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reset Pencarian'),
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
        title: const Text('Kelola Device IoT'),
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
            onPressed: () {
              ServerStatusIndicator.checkNow();
              _handleManualRefresh();
            },
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
            _buildSummarySection(),
            _buildSearchCard(),
            if (_isLoading && _filteredDevices.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_hasError && _filteredDevices.isEmpty)
              _buildErrorState()
            else if (_filteredDevices.isEmpty)
              _buildEmptyState()
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: _filteredDevices
                      .map(_buildDeviceCard)
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ADD / EDIT IOT DEVICE SCREEN (TIDAK BERUBAH)
// ============================================================
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
        final msg = Helpers.extractBackendMessage(
          e,
          fallback: 'Gagal menyimpan perangkat. Silakan coba lagi.',
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