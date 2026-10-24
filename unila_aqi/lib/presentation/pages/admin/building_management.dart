import 'package:flutter/material.dart';
import '../../../data/repositories/building_repository.dart';
import '../../../data/models/building.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/constants/colors.dart';
import '../../../core/services/storage_service.dart';
import '../../widgets/common/server_status_indicator.dart';

class BuildingManagementScreen extends StatefulWidget {
  const BuildingManagementScreen({super.key});

  @override
  State<BuildingManagementScreen> createState() =>
      _BuildingManagementScreenState();
}

class _BuildingManagementScreenState extends State<BuildingManagementScreen> {
  final BuildingRepository _buildingRepository = BuildingRepository();
  final StorageService _storage = StorageService();
  final TextEditingController _searchController = TextEditingController();

  static const String _cacheKey = 'cache_buildings';

  List<Building> _buildings = [];
  List<Building> _filteredBuildings = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadCacheThenFetch();
  }

  /// 1) Muat cache dulu agar konten terakhir tampil,
  /// 2) lalu fetch dari server untuk update terbaru.
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
                Building.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (mounted) {
          setState(() {
            _buildings = list;
          });
          _filterBuildings(_searchController.text);
        }
      } catch (_) {
        // cache rusak — abaikan
      }
    }

    await _loadBuildings();
  }

  Future<void> _loadBuildings() async {
    setState(() {
      // Spinner hanya jika belum ada data (cache kosong)
      _isLoading = _buildings.isEmpty;
      _hasError = false;
    });

    try {
      final buildings = await _buildingRepository.getBuildings();
      if (!mounted) return;

      setState(() {
        _buildings = buildings;
      });
      _filterBuildings(_searchController.text);

      // Simpan cache
      try {
        await _storage.setJson(_cacheKey, {
          'data': buildings.map((b) => b.toJson()).toList(),
        });
      } catch (_) {}
        } catch (e) {
      if (!mounted) return;

      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
      } else {
        Helpers.showSnackBar(
          context,
          'Gagal memuat data gedung',
          isError: true,
        );
      }

      // Tampilkan error state HANYA jika tidak ada cache sama sekali
      if (_buildings.isEmpty) {
        setState(() {
          _hasError = true;
          _errorMessage = Helpers.friendlyErrorMessage(e);
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterBuildings(String query) {
    if (query.isEmpty) {
      setState(() => _filteredBuildings = _buildings);
    } else {
      final filtered = _buildings.where((building) {
        final name = building.name.toLowerCase();
        final code = building.code?.toLowerCase() ?? '';
        final search = query.toLowerCase();
        return name.contains(search) || code.contains(search);
      }).toList();
      setState(() => _filteredBuildings = filtered);
    }
  }

  Future<void> _deleteBuilding(String buildingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Gedung'),
        content: const Text('Apakah Anda yakin ingin menghapus gedung ini?'),
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
      await _buildingRepository.deleteBuilding(buildingId);
      await _loadBuildings();
      if (mounted) {
        Helpers.showSnackBar(context, 'Gedung berhasil dihapus');
      }
    } catch (e) {
      if (!mounted) return;
      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
      } else {
        Helpers.showSnackBar(
          context,
          'Gagal menghapus gedung: $e',
          isError: true,
        );
      }
    }
  }

  void _navigateToAddBuilding() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditBuildingScreen(
          onBuildingSaved: _loadBuildings,
        ),
      ),
    );
  }

  void _navigateToEditBuilding(Building building) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditBuildingScreen(
          building: building,
          onBuildingSaved: _loadBuildings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Gedung'),
        actions: [
          const ServerStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ServerStatusIndicator.checkNow();
              _loadBuildings();
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
                hintText: '🔍 Cari gedung...',
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
                          _filterBuildings('');
                        },
                      )
                    : null,
              ),
              onChanged: _filterBuildings,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToAddBuilding,
                icon: const Icon(Icons.add),
                label: const Text('TAMBAH GEDUNG'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading && _filteredBuildings.isEmpty)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
                    else if (_hasError && _filteredBuildings.isEmpty)
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
                        onPressed: _loadBuildings,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_filteredBuildings.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_city_outlined,
                        size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Tidak ada gedung ditemukan',
                      style:
                          TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    if (_searchController.text.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          _filterBuildings('');
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
                itemCount: _filteredBuildings.length,
                itemBuilder: (context, index) {
                  final building = _filteredBuildings[index];
                  return _buildBuildingCard(building);
                },
              ),
            ),

          Container(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Total: ${_filteredBuildings.length} gedung',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuildingCard(Building building) {
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
                        building.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (building.code != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Kode: ${building.code}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${building.roomCount} ruangan',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            if (building.description != null &&
                building.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  building.description!,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.grey),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Dibuat: ${Helpers.formatDateTime(building.createdAt)}',
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _navigateToEditBuilding(building),
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
                    onPressed: () => _deleteBuilding(building.id),
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

class AddEditBuildingScreen extends StatefulWidget {
  final Building? building;
  final VoidCallback onBuildingSaved;

  const AddEditBuildingScreen({
    super.key,
    this.building,
    required this.onBuildingSaved,
  });

  bool get isEditing => building != null;

  @override
  State<AddEditBuildingScreen> createState() =>
      _AddEditBuildingScreenState();
}

class _AddEditBuildingScreenState extends State<AddEditBuildingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final BuildingRepository _buildingRepository = BuildingRepository();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final building = widget.building!;
      _nameController.text = building.name;
      _codeController.text = building.code ?? '';
      _descriptionController.text = building.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveBuilding() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (widget.isEditing) {
        await _buildingRepository.updateBuilding(
          id: widget.building!.id,
          name: _nameController.text.trim(),
          code: _codeController.text.trim().isEmpty
              ? null
              : _codeController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
        if (mounted) {
          Helpers.showSnackBar(context, 'Gedung berhasil diperbarui');
        }
      } else {
        await _buildingRepository.createBuilding(
          name: _nameController.text.trim(),
          code: _codeController.text.trim().isEmpty
              ? null
              : _codeController.text.trim(),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
        );
        if (mounted) {
          Helpers.showSnackBar(context, 'Gedung berhasil ditambahkan');
        }
      }

      widget.onBuildingSaved();

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
      } else {
        Helpers.showSnackBar(
          context,
          'Gagal menyimpan gedung: $e',
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
        title:
            Text(widget.isEditing ? 'Edit Gedung' : 'Tambah Gedung'),
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
              const Text('Nama Gedung*',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Gedung H, Gedung MIPA',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama gedung wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Kode Gedung',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  hintText: 'Contoh: H, M, A (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Deskripsi',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  hintText: 'Deskripsi gedung (opsional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveBuilding,
                  child: Text(
                    widget.isEditing
                        ? 'SIMPAN PERUBAHAN'
                        : 'SIMPAN GEDUNG',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.isEditing)
                Text(
                  '*Wajib diisi',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}