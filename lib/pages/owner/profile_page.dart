import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../main.dart';
import 'staff_approval_page.dart';
import 'category_page.dart';
import 'wallet_page.dart';

class ProfilePage extends StatefulWidget {
  final int? userId;
  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _blue = Color(0xFF1155D9);

  bool isLoading = true;

  // Data dari /auth/me
  String ownerName = '';
  String ownerEmail = '';
  String storeName = '';
  String userRole = '';
  String? _profilePhotoUrl;

  File? _imageFile;
  bool _isUploadingPhoto = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      ownerName = prefs.getString('saved_owner_name') ?? '';
      storeName = prefs.getString('saved_store_name') ?? '';
      ownerEmail = prefs.getString('saved_email') ?? '';

      final savedPhotoPath = prefs.getString('saved_profile_photo_path');
      if (savedPhotoPath != null && savedPhotoPath.isNotEmpty) {
        _profilePhotoUrl = ApiService.resolvePhotoUrl(savedPhotoPath);
      }

      // Ambil data terbaru dari API
      final me = await ApiService.getCurrentUser();
      if (me != null) {
        final user = me['user'];
        if (user is Map) {
          if (user['name'] != null) ownerName = user['name'].toString();
          if (user['email'] != null) ownerEmail = user['email'].toString();
          if (user['role'] != null) userRole = user['role'].toString();
          if (user['profile_photo'] != null && user['profile_photo'].toString().isNotEmpty) {
            _profilePhotoUrl = ApiService.resolvePhotoUrl(user['profile_photo'].toString());
          }
        }
        final business = me['business'];
        if (business is Map && business['name'] != null) {
          storeName = business['name'].toString();
        }
      }
    } catch (e) {
      debugPrint('Gagal load profil: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    if (_isUploadingPhoto) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (pickedFile == null) return;

      final File imageFile = File(pickedFile.path);

      setState(() {
        _imageFile = imageFile;
        _isUploadingPhoto = true;
      });

      final result = await ApiService.uploadProfilePhoto(imageFile);

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _profilePhotoUrl = result['photo_url'] as String?;
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diperbarui!')),
        );
      } else {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal mengunggah foto')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengambil foto: $e')));
      }
    }
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
        title: const Text('Konfirmasi Keluar'),
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
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.storefront, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CASHMATE UMKM', style: TextStyle(color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.bold)),
                Text('Toko & Profil', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
              ],
            ),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadProfileData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            // ---- Kartu Identitas ----
            _buildIdentityCard(theme),
            const SizedBox(height: 20),

            // ---- Kelola Usaha ----
            _sectionHeader('Kelola Usaha', theme),
            const SizedBox(height: 8),
            _menuItem(
              icon: Icons.group_outlined,
              label: 'Manajemen Staff',
              subtitle: 'Tambah, nonaktifkan, atau pulihkan Staff',
              theme: theme,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffApprovalPage())),
            ),
            _menuItem(
              icon: Icons.savings_outlined,
              label: 'Kantong Kas / Wallet',
              subtitle: 'Kelola wallet aktif dan nonaktif',
              theme: theme,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage())),
            ),
            _menuItem(
              icon: Icons.category_outlined,
              label: 'Kategori Transaksi',
              subtitle: 'Kelola kategori pemasukan & pengeluaran',
              theme: theme,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryPage())),
            ),
            const SizedBox(height: 20),

            // ---- Tampilan & Keamanan ----
            _sectionHeader('Tampilan & Keamanan', theme),
            const SizedBox(height: 8),
            _buildThemeToggle(theme, isDark),
            const SizedBox(height: 20),

            // ---- Keluar ----
            _buildLogoutButton(theme),
            const SizedBox(height: 16),

            // ---- Info versi ----
            Center(
              child: Text(
                'CashMate v1.0.0 — MVP',
                style: TextStyle(fontSize: 11, color: theme.hintColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          // Foto profil
          GestureDetector(
            onTap: _pickAndUploadProfilePhoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: _blue.withOpacity(0.15),
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                      ? NetworkImage(_profilePhotoUrl!) as ImageProvider
                      : null),
                  child: (_imageFile == null && (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty))
                      ? Text(
                    ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'O',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _blue),
                  )
                      : null,
                ),
                if (_isUploadingPhoto)
                  const Positioned.fill(
                    child: CircleAvatar(
                      backgroundColor: Colors.black38,
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    ),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _blue,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.cardColor, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ownerName.isNotEmpty ? ownerName : 'Owner',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                ),
                const SizedBox(height: 2),
                Text(ownerEmail, style: TextStyle(fontSize: 12, color: theme.hintColor)),
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
                        userRole.isNotEmpty ? userRole.toUpperCase() : 'OWNER',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _blue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (storeName.isNotEmpty)
                      Flexible(
                        child: Text(
                          storeName,
                          style: TextStyle(fontSize: 11, color: theme.hintColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: theme.hintColor,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required ThemeData theme,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _blue, size: 20),
        ),
        title: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: theme.textTheme.bodyLarge?.color)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 11, color: theme.hintColor)),
        trailing: Icon(Icons.chevron_right, color: theme.hintColor, size: 20),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildThemeToggle(ThemeData theme, bool isDark) {
    return Container(
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
    );
  }

  Widget _buildLogoutButton(ThemeData theme) {
    return Container(
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
    );
  }
}