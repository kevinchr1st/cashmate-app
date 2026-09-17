import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../main.dart';

/// Halaman profil/akun Staff: informasi user, business, role, tema, logout.
/// Data dari /auth/me. Tidak ada printer/POS/paper saver/shift settings.
class StaffProfilePage extends StatefulWidget {
  final int userId;
  const StaffProfilePage({super.key, this.userId = 1});

  @override
  State<StaffProfilePage> createState() => _StaffProfilePageState();
}

class _StaffProfilePageState extends State<StaffProfilePage> {
  static const _blue = Color(0xFF0D6EFD);

  String staffName = '';
  String staffEmail = '';
  String businessName = '';
  String userRole = 'STAFF';

  @override
  void initState() {
    super.initState();
    _loadStaffInfo();
  }

  Future<void> _loadStaffInfo() async {
    final me = await ApiService.getCurrentUser();
    if (!mounted || me == null) return;
    setState(() {
      final user = me['user'];
      if (user is Map) {
        if (user['name'] != null) staffName = user['name'].toString();
        if (user['email'] != null) staffEmail = user['email'].toString();
        if (user['role'] != null) userRole = user['role'].toString().toUpperCase();
      }
      final business = me['business'];
      if (business is Map && business['name'] != null) {
        businessName = business['name'].toString();
      }
    });
  }

  Future<void> _changeThemeMode(bool isDark) async {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isDark ? 'Mode Gelap Diaktifkan' : 'Mode Terang Diaktifkan')),
      );
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Akun'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun CashMate?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFCE8E6)),
            onPressed: () async {
              Navigator.pop(context);
              await ApiService.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('Keluar', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Text('Akun Saya', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
        children: [
          // ---- Identity card ----
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: _blue.withOpacity(0.15),
                  child: Text(
                    staffName.isNotEmpty ? staffName[0].toUpperCase() : 'S',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _blue),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staffName.isNotEmpty ? staffName : 'Staff',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                      ),
                      const SizedBox(height: 2),
                      Text(staffEmail, style: TextStyle(fontSize: 12, color: theme.hintColor)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              userRole,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _blue),
                            ),
                          ),
                          if (businessName.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(businessName, style: TextStyle(fontSize: 11, color: theme.hintColor), overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ---- Theme toggle ----
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            ),
            child: SwitchListTile(
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: _blue, size: 20),
              ),
              title: Text('Mode Gelap', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: theme.textTheme.bodyLarge?.color)),
              subtitle: Text(isDark ? 'Tema gelap aktif' : 'Tema terang aktif', style: TextStyle(fontSize: 11, color: theme.hintColor)),
              value: isDark,
              onChanged: _changeThemeMode,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 20),

          // ---- Logout ----
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.red.withOpacity(0.15)),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: Colors.red, size: 20),
              ),
              title: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Colors.red)),
              subtitle: Text('Logout dari akun CashMate', style: TextStyle(fontSize: 11, color: theme.hintColor)),
              trailing: const Icon(Icons.chevron_right, color: Colors.red, size: 20),
              onTap: _showLogoutConfirmation,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 20),

          Center(
            child: Text('CashMate v1.0.0 — MVP', style: TextStyle(fontSize: 11, color: theme.hintColor)),
          ),
        ],
      ),
    );
  }
}