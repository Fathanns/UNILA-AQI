import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/colors.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/repositories/building_repository.dart';
import '../../../data/repositories/room_repository.dart';
import '../../../data/repositories/iot_device_repository.dart';
import '../../providers/auth_provider.dart';
import '../../../core/services/storage_service.dart';
import '../../widgets/common/server_status_indicator.dart';

class ProfileManagementScreen extends StatefulWidget {
  const ProfileManagementScreen({super.key});

  @override
  State<ProfileManagementScreen> createState() =>
      _ProfileManagementScreenState();
}

class _ProfileManagementScreenState extends State<ProfileManagementScreen> {
  final _profileRepository = ProfileRepository();
  final _buildingRepository = BuildingRepository();
  final _roomRepository = RoomRepository();
  final _deviceRepository = IoTDeviceRepository();
  final StorageService _storage = StorageService();
  static const String _cacheKey = 'cache_profile';

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _hasError = false;
  String _errorForLog = ''; // hanya untuk debugging, TIDAK ditampilkan

  String _username = '';
  String _email = '';
  DateTime? _lastLogin;

  int _buildingCount = 0;
  int _roomCount = 0;
  int _deviceCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<int> _safeCount<T>(Future<List<T>> future) async {
    try {
      return (await future).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _loadData() async {
    // 1) Muat cache dulu (jika ada)
    bool hadCache = false;
    try {
      final cached = _storage.getJson(_cacheKey);
      if (cached != null) {
        if (mounted) {
          setState(() {
            _username = cached['username']?.toString() ?? '';
            _email = cached['email']?.toString() ?? '';
            _lastLogin = cached['lastLogin'] != null
                ? DateTime.tryParse(cached['lastLogin'].toString())
                : null;
            _buildingCount =
                (cached['buildingCount'] as num?)?.toInt() ?? 0;
            _roomCount = (cached['roomCount'] as num?)?.toInt() ?? 0;
            _deviceCount =
                (cached['deviceCount'] as num?)?.toInt() ?? 0;
            _isLoading = false;
          });
          hadCache = _username.isNotEmpty;
        }
      }
    } catch (_) {
      // cache rusak — abaikan, lanjut fetch server
    }

    setState(() {
      _isLoading = !hadCache;
      _hasError = false;
      _errorForLog = '';
    });

    // 2) Fetch dari server
    try {
      final profileFuture = _profileRepository.getProfile();
      final countsFuture = Future.wait<int>([
        _safeCount(_buildingRepository.getBuildings()),
        _safeCount(_roomRepository.getRooms()),
        _safeCount(_deviceRepository.getDevices()),
      ]);

      final profile = await profileFuture;
      final counts = await countsFuture;

      final user = profile['user'] as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        _username = user['username']?.toString() ?? '';
        _email = user['email']?.toString() ?? '';
        _lastLogin = user['lastLogin'] != null
            ? DateTime.parse(user['lastLogin'].toString()).toLocal()
            : null;
        _buildingCount = counts[0];
        _roomCount = counts[1];
        _deviceCount = counts[2];
        _isLoading = false;
        _hasError = false;
      });

      // Simpan cache
      try {
        await _storage.setJson(_cacheKey, {
          'username': _username,
          'email': _email,
          'lastLogin': _lastLogin?.toIso8601String(),
          'buildingCount': _buildingCount,
          'roomCount': _roomCount,
          'deviceCount': _deviceCount,
        });
      } catch (_) {}
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        // Tampilkan error state HANYA jika tidak ada cache
        if (!hadCache) {
          _hasError = true;
          _errorForLog = e.toString(); // untuk debug saja
        }
      });

      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
      } else {
        Helpers.showSnackBar(
          context,
          'Gagal memuat profil',
          isError: true,
        );
      }
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

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
            'Apakah Anda yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final authProvider =
        Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    }
  }

  void _navigateToEditProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          currentUsername: _username,
          currentEmail: _email,
         onSaved: _loadData,
        ),
      ),
    );
  }

  void _navigateToChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const ChangePasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
     appBar: AppBar(
      title: const Text('Profil Admin'),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    // Pesan di sini DIJAMIN ramah — tidak bergantung pada string error.
    final isNetwork = Helpers.isNetworkError(_errorForLog);

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
              'Tidak dapat memuat profil',
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

  Widget _buildContent() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 16),
            _buildInfoSection(),
            const SizedBox(height: 16),
            _buildSummarySection(),
            const SizedBox(height: 16),
            _buildActionSection(),
            const SizedBox(height: 32),
            _buildFooter(),
            const SizedBox(height: 48),   
        ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
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
            child: const Icon(Icons.admin_panel_settings,
                size: 48, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            _username,
            style: const TextStyle(
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
            child: const Text(
              'ADMINISTRATOR',
              style: TextStyle(
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
              onPressed: _navigateToEditProfile,
              icon: const Icon(Icons.edit,
                  size: 18, color: Colors.white),
              label: const Text(
                'EDIT PROFIL',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(
                    color: Colors.white, width: 1.5),
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

  Widget _buildInfoSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Informasi Akun',
                    style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow(
              icon: Icons.person_outline,
              label: 'Username',
              value: _username,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: _email.isEmpty ? '-' : _email,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              icon: Icons.access_time,
              label: 'Login Terakhir',
              value: _lastLogin != null
                  ? Helpers.formatDateTime(_lastLogin!)
                  : 'Belum pernah login',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('Ringkasan',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.location_city,
                  label: 'Gedung',
                  value: _buildingCount.toString(),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.meeting_room,
                  label: 'Ruangan',
                  value: _roomCount.toString(),
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.sensors,
                  label: 'Device IoT',
                  value: _deviceCount.toString(),
                  color: AppColors.info,
                ),
              ),
            ],
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

  Widget _buildActionSection() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildActionTile(
            icon: Icons.lock_outline,
            label: 'Ganti Password',
            onTap: _navigateToChangePassword,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildActionTile(
            icon: Icons.logout,
            label: 'Logout',
            onTap: _logout,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? AppColors.error : AppColors.primary;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDestructive
              ? AppColors.error
              : AppColors.textPrimary,
          fontFamily: 'Inter',
        ),
      ),
      trailing: Icon(Icons.chevron_right, size: 20, color: color),
      onTap: onTap,
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        'v 1.0.0',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.textHint,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}

// ============================================================
// EDIT PROFILE
// ============================================================
class EditProfileScreen extends StatefulWidget {
  final String currentUsername;
  final String currentEmail;
  final Future<void> Function() onSaved;

  const EditProfileScreen({
    super.key,
    required this.currentUsername,
    required this.currentEmail,
    required this.onSaved,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _profileRepository = ProfileRepository();

  bool _isLoading = false;
  bool _isSendingCode = false;
  bool _codeSent = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _usernameController.text = widget.currentUsername;
    _emailController.text = widget.currentEmail;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  bool get _isEmailChanged {
    return _emailController.text.trim().toLowerCase() !=
        widget.currentEmail.trim().toLowerCase();
  }

  Future<void> _sendEmailCode() async {
    final email = _emailController.text.trim();

    final emailError = Validators.validateEmail(email);
    if (emailError != null) {
      Helpers.showSnackBar(context, emailError, isError: true);
      return;
    }

    if (!_isEmailChanged) {
      Helpers.showSnackBar(
        context,
        'Email baru sama dengan email saat ini',
        isError: true,
      );
      return;
    }

    setState(() => _isSendingCode = true);

    try {
      await _profileRepository.requestEmailChangeCode(email);

      if (!mounted) return;

      setState(() => _codeSent = true);

      Helpers.showSnackBar(
        context,
        'Kode verifikasi telah dikirim ke $email',
      );
    } catch (e) {
      if (!mounted) return;

      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
      } else {
        final msg = Helpers.extractBackendMessage(
          e,
          fallback: 'Gagal mengirim kode verifikasi. Coba lagi.',
        );
        Helpers.showSnackBar(context, msg, isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingCode = false);
      }
    }
  }

  Future<void> _handleRefresh() async {
  if (_isRefreshing) return;
  setState(() => _isRefreshing = true);
  try {
    await widget.onSaved();
  } finally {
    if (mounted) setState(() => _isRefreshing = false);
  }
}

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final emailChanged = email.toLowerCase() !=
        widget.currentEmail.trim().toLowerCase();

    if (emailChanged) {
      final code = _codeController.text.trim();

      if (code.length != 6) {
        Helpers.showSnackBar(
          context,
          'Masukkan 6 digit kode verifikasi email',
          isError: true,
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      await _profileRepository.updateProfile(
        username: _usernameController.text.trim(),
        email: email.isEmpty ? null : email,
        emailChangeCode:
            emailChanged ? _codeController.text.trim() : null,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'username', _usernameController.text.trim());

      if (mounted) {
        final authProvider =
            Provider.of<AuthProvider>(context, listen: false);
        await authProvider.initialize();
      }

      widget.onSaved();

      if (mounted) {
        Helpers.showSnackBar(context, 'Profil berhasil diperbarui');
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;

      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
      } else {
        final msg = Helpers.extractBackendMessage(
          e,
          fallback: 'Gagal menyimpan profil. Coba lagi.',
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
        title: const Text('Profil Admin'),
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
              _handleRefresh();
            },
            splashRadius: 20,
            tooltip: 'Refresh',
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
              const Text('Username*',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  hintText: 'Masukkan username',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) =>
                    Validators.validateRequired(value, 'Username'),
              ),
              const SizedBox(height: 16),
              const Text('Email',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  hintText: 'Masukkan email (opsional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {
                  _codeSent = false;
                  _codeController.clear();
                }),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  return Validators.validateEmail(value);
                },
              ),

              if (_isEmailChanged) ...[
                const SizedBox(height: 16),
                const Text(
                  'Kode Verifikasi Email*',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          hintText: 'Masukkan 6 digit kode',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.verified_outlined),
                          counterText: '',
                        ),
                        validator: (value) {
                          if (!_isEmailChanged) return null;
                          if (value == null ||
                              value.trim().length != 6) {
                            return 'Masukkan 6 digit kode verifikasi';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed:
                            _isSendingCode ? null : _sendEmailCode,
                        child: _isSendingCode
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            : Text(_codeSent
                                ? 'Kirim Ulang'
                                : 'Kirim Kode'),
                      ),
                    ),
                  ],
                ),
                if (_codeSent)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Kode dikirim ke ${_emailController.text.trim()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: const Text(
                    'SIMPAN PERUBAHAN',
                    style: TextStyle(
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

// ============================================================
// CHANGE PASSWORD
// ============================================================
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  final _profileRepository = ProfileRepository();

  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _profileRepository.changePassword(
        oldPassword: _oldController.text,
        newPassword: _newController.text,
      );
      if (mounted) {
        Helpers.showSnackBar(context, 'Password berhasil diubah');
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;

      if (Helpers.isNetworkError(e)) {
        Helpers.showServerError(context);
      } else {
        final msg = Helpers.extractBackendMessage(
          e,
          fallback: 'Gagal mengubah password. Coba lagi.',
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
        title: const Text('Ganti Password'),
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
              const Text('Password Lama*',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _oldController,
                obscureText: _obscureOld,
                decoration: InputDecoration(
                  hintText: 'Masukkan password lama',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureOld
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscureOld = !_obscureOld),
                  ),
                ),
                validator: (value) =>
                    Validators.validateRequired(value, 'Password lama'),
              ),
              const SizedBox(height: 16),
              const Text('Password Baru*',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _newController,
                obscureText: _obscureNew,
                decoration: InputDecoration(
                  hintText: 'Minimal 8 karakter, huruf dan angka',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
                validator: Validators.validatePassword,
              ),
              const SizedBox(height: 16),
              const Text('Konfirmasi Password Baru*',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _confirmController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  hintText: 'Ulangi password baru',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () => setState(
                        () => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
                validator: (value) =>
                    Validators.validateConfirmPassword(
                  value,
                  _newController.text,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ketentuan Password:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        fontFamily: 'Inter',
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Minimal 8 karakter\n• Kombinasi huruf dan angka',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: const Text(
                    'GANTI PASSWORD',
                    style: TextStyle(
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