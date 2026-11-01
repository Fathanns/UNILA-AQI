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
  bool _isRefreshing = false;
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

  Future<void> _handleManualRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await _loadBuildings();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

      void _filterBuildings(String query) {
    List<Building> filtered = _buildings;

    if (query.isNotEmpty) {
      final search = query.toLowerCase();
      filtered = filtered.where((building) {
        final name = building.name.toLowerCase();
        final code = building.code?.toLowerCase() ?? '';
        return name.contains(search) || code.contains(search);
      }).toList();
    }

    // ✅ URUTAN: waktu dibuat ASCENDING (terlama di atas).
    // Jika createdAt sama (mis. di-seed dalam milidetik yang sama),
    // fallback ke nama gedung (alfabetis), lalu _id sebagai tie-breaker
    // terakhir agar urutan benar-benar deterministik.
    filtered = List<Building>.from(filtered)
      ..sort((a, b) {
        final cmpTime = a.createdAt.compareTo(b.createdAt);
        if (cmpTime != 0) return cmpTime;

        final cmpName =
            a.name.toLowerCase().compareTo(b.name.toLowerCase());
        if (cmpName != 0) return cmpName;

        return a.id.compareTo(b.id);
      });

    if (mounted) {
      setState(() => _filteredBuildings = filtered);
    } else {
      _filteredBuildings = filtered;
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
        final msg = Helpers.extractBackendMessage(
          e,
          fallback: 'Gagal menghapus gedung. Silakan coba lagi.',
        );
        Helpers.showSnackBar(context, msg, isError: true);
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
            child: const Icon(Icons.location_city,
                size: 44, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Kelola Gedung',
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
              '${_buildings.length} GEDUNG TERDAFTAR',
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
              onPressed: _navigateToAddBuilding,
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: const Text(
                'TAMBAH GEDUNG',
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
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cari gedung...',
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
                    _filterBuildings('');
                  },
                )
              : null,
        ),
        onChanged: _filterBuildings,
      ),
    );
  }

  Widget _buildBuildingCard(Building building) {
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
                    Icons.location_city,
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
                        building.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontFamily: 'Inter',
                        ),
                      ),
                      if (building.code != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Kode: ${building.code}',
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
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.meeting_room,
                          size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '${building.roomCount}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (building.description != null &&
                building.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                building.description!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.4,
                  fontFamily: 'Inter',
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 12, color: AppColors.textHint),
                const SizedBox(width: 6),
                 Text(
                  'Dibuat: ${Helpers.formatDateTime(building.createdAt.toLocal())}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: _buildCardAction(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    color: AppColors.primary,
                    onTap: () => _navigateToEditBuilding(building),
                  ),
                ),
                Container(width: 1, height: 24, color: AppColors.border),
                Expanded(
                  child: _buildCardAction(
                    icon: Icons.delete_outline,
                    label: 'Hapus',
                    color: AppColors.error,
                    onTap: () => _deleteBuilding(building.id),
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
              onPressed: _loadBuildings,
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
              hasSearch ? Icons.search_off : Icons.location_city_outlined,
              size: 64,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Tidak ada gedung yang cocok dengan\n"${_searchController.text.trim()}"'
                  : 'Belum ada gedung terdaftar',
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
                  _filterBuildings('');
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
        title: const Text('Kelola Gedung'),
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
            _buildSearchCard(),
            if (_isLoading && _filteredBuildings.isEmpty)
              const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_hasError && _filteredBuildings.isEmpty)
              _buildErrorState()
            else if (_filteredBuildings.isEmpty)
              _buildEmptyState()
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Column(
                  children: _filteredBuildings
                      .map(_buildBuildingCard)
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
// ADD / EDIT BUILDING SCREEN (TIDAK BERUBAH)
// ============================================================
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
        final msg = Helpers.extractBackendMessage(
          e,
          fallback: 'Gagal menyimpan gedung. Silakan coba lagi.',
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
            ],
          ),
        ),
      ),
    );
  }
}