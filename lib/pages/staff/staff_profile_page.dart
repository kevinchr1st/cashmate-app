import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../main.dart';

/// Halaman profil/akun Staff CashMate:
/// Memungkinkan Staff melihat data akun, mengubah foto profil (via Kamera/Galeri),
/// mengubah mode tema, dan logout.
class StaffProfilePage extends StatefulWidget {
  final int userId;
  const StaffProfilePage({super.key, this.userId = 1});

  @override
  State<StaffProfilePage> createState() => _StaffProfilePageState();
}

class _StaffProfilePageState extends State<StaffProfilePage> {
  static const _blue = Color(0xFF0D6EFD);
  static const _amber = Color(0xFFFFB800);

  String staffName = '';
  String staffEmail = '';
  String businessName = '';
  String userRole = 'STAFF';
  String? profilePhotoUrl;
  bool isUploading = false;
  final ImagePicker _picker = ImagePicker();

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
        if (user['profile_photo'] != null && user['profile_photo'].toString().isNotEmpty) {
          profilePhotoUrl = ApiService.resolvePhotoUrl(user['profile_photo'].toString());
        }
      }
      final business = me['business'];
      if (business is Map && business['name'] != null) {
        businessName = business['name'].toString();
      }
    });
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      setState(() => isUploading = true);

      final result = await ApiService.uploadProfilePhoto(File(pickedFile.path));

      if (!mounted) return;
      setState(() => isUploading = false);

      if (result['success'] == true) {
        final newUrl = result['photo_url']?.toString();
        setState(() {
          if (newUrl != null && newUrl.isNotEmpty) {
            profilePhotoUrl = newUrl;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Foto profil berhasil diperbarui'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Gagal mengunggah foto profil'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih foto: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showPhotoSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.hintColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ubah Foto Profil Staff',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _photoOptionTile(
                      icon: Icons.camera_alt_rounded,
                      label: 'Kamera',
                      color: _blue,
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndUploadPhoto(ImageSource.camera);
                      },
                    ),
                    _photoOptionTile(
                      icon: Icons.photo_library_rounded,
                      label: 'Galeri Foto',
                      color: _amber,
                      onTap: () {
                        Navigator.pop(context);
                        _pickAndUploadPhoto(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _photoOptionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
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
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Akun'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun CashMate?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFCE8E6)),
            onPressed: () async {
              Navigator.pop(dialogContext);
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
            Text('Profil Staff', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStaffInfo,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          children: [
            // ---- Card Identitas & Foto Profil ----
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [Colors.white, const Color(0xFFF8FAFC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _blue.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: isUploading ? null : _showPhotoSourceBottomSheet,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: _blue, width: 2.5),
                          ),
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: _blue.withValues(alpha: 0.12),
                            backgroundImage: (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty)
                                ? NetworkImage(profilePhotoUrl!)
                                : null,
                            child: isUploading
                                ? const CircularProgressIndicator(color: _blue)
                                : (profilePhotoUrl == null || profilePhotoUrl!.isEmpty)
                                ? Text(
                              staffName.isNotEmpty ? staffName[0].toUpperCase() : 'S',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _blue),
                            )
                                : null,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: isUploading ? null : _showPhotoSourceBottomSheet,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                              color: _amber,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                            ),
                            child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    staffName.isNotEmpty ? staffName : 'Staff Kasir',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                  ),
                  const SizedBox(height: 2),
                  Text(staffEmail, style: TextStyle(fontSize: 12, color: theme.hintColor)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _blue.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.badge_outlined, size: 12, color: _blue),
                            const SizedBox(width: 4),
                            Text(
                              userRole,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _blue),
                            ),
                          ],
                        ),
                      ),
                      if (businessName.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _amber.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.storefront_rounded, size: 12, color: _amber),
                              const SizedBox(width: 4),
                              Text(
                                businessName,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _amber),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _showPhotoSourceBottomSheet,
                    icon: const Icon(Icons.edit, size: 14, color: _blue),
                    label: const Text('Ganti Foto Profil', style: TextStyle(fontSize: 12, color: _blue, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _blue.withValues(alpha: 0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---- Pengaturan & Aplikasi ----
            Text('Pengaturan Aplikasi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.hintColor)),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
              ),
              child: SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _blue.withValues(alpha: 0.1),
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
            const SizedBox(height: 12),

            // ---- Petunjuk Kasir ----
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.help_outline_rounded, color: Colors.teal, size: 20),
                ),
                title: Text('Panduan Staff / Kasir', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: theme.textTheme.bodyLarge?.color)),
                subtitle: Text('Cara mencatat transaksi & upload nota', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (dialogCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Panduan Kasir CashMate'),
                      content: const SingleChildScrollView(
                        child: Text(
                          '1. Pilih tombol "+ Catat Pemasukan" atau "- Catat Pengeluaran" di Beranda.\n\n'
                              '2. Pilih Dompet (Cash, Transfer, QRIS) dan Kategori yang sesuai.\n\n'
                              '3. Masukkan jumlah nominal dan deskripsi singkat.\n\n'
                              '4. Anda bisa melampirkan foto nota dengan menekan ikon Kamera saat membuat transaksi.\n\n'
                              '5. Transaksi yang Anda catat hari ini dapat dilihat pada tab "Aktivitas".',
                          style: TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Mengerti')),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // ---- Logout ----
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout, color: Colors.red, size: 20),
                ),
                title: const Text('Keluar Akun', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Colors.red)),
                subtitle: Text('Logout dari akun Staff CashMate', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                trailing: const Icon(Icons.chevron_right, color: Colors.red, size: 20),
                onTap: _showLogoutConfirmation,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 24),

            Center(
              child: Column(
                children: [
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(text: 'Cash', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _blue)),
                        TextSpan(text: 'Mate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _amber)),
                        TextSpan(text: ' Staff v1.0.0', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}