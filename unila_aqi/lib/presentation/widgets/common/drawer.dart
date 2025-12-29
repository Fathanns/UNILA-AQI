import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../presentation/providers/auth_provider.dart';
import '../../../core/constants/colors.dart';

class AppDrawer extends StatelessWidget {
  final bool isAdmin;
  final VoidCallback? onDashboardTap;
  final VoidCallback? onBuildingsTap;
  final VoidCallback? onRoomsTap;
  final VoidCallback? onDevicesTap;
  final VoidCallback? onProfileTap;
  final VoidCallback? onLogoutTap;
  
  const AppDrawer({
    super.key,
    required this.isAdmin,
    this.onDashboardTap,
    this.onBuildingsTap,
    this.onRoomsTap,
    this.onDevicesTap,
    this.onProfileTap,
    this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    
    return Drawer(
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 24),
            color: AppColors.primary,
            child: Column(
              children: [
                Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primary,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white,
                    blurRadius: 1.5,
                    offset: const Offset(1, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0), // Padding untuk memberi ruang
                child: Image.asset(
                  'assets/images/logo_unila.png',
                  width: 104, // 120 - (8*2) = 104
                  height: 104,
                  fit: BoxFit.contain, // Gunakan contain agar tidak terpotong
                ),
              ),
            ),
                const SizedBox(height: 16),
                Text(
                  'UNILA Air Quality Index',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // User Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isAdmin ? Icons.admin_panel_settings : Icons.person,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser?['username'] ?? (isAdmin ? 'Admin' : 'Pengunjung'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isAdmin ? '● Online' : 'Pengguna',
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
              ],
            ),
          ),
          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildMenuItem(
                  icon: Icons.dashboard,
                  label: 'DASHBOARD',
                  onTap: onDashboardTap,
                ),
                if (isAdmin) ...[
                  const Divider(indent: 16, endIndent: 16),
                  _buildMenuItem(
                    icon: Icons.location_city,
                    label: 'KELOLA GEDUNG',
                    onTap: onBuildingsTap,
                  ),
                  _buildMenuItem(
                    icon: Icons.meeting_room,
                    label: 'KELOLA RUANGAN',
                    onTap: onRoomsTap,
                  ),
                  _buildMenuItem(
                    icon: Icons.sensors,
                    label: 'KELOLA DEVICE IOT',
                    onTap: onDevicesTap,
                  ),
                  _buildMenuItem(
                    icon: Icons.person,
                    label: 'EDIT PROFILE ADMIN',
                    onTap: onProfileTap,
                  ),
                ],
              ],
            ),
          ),
          // Logout Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onLogoutTap,
                icon: const Icon(Icons.logout),
                label: const Text('LOGOUT'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ),
          ),
          // Version Info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'v1.0.0',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}