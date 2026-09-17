import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';

/// Halaman profil/akun Staff CashMate:
/// melihat data akun, mengubah foto profil (Kamera/Galeri),
/// mengubah mode tema, dan logout.
class StaffProfilePage extends StatefulWidget {
  final int userId;
  const StaffProfilePage({super.key, this.userId = 1});

  @override
  State<StaffProfilePage> createState() => _StaffProfilePageState();
}

class _StaffProfilePageState extends State<StaffProfilePage> {
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
        final photo = (user['profile_photo'] ?? '').toString();
        if (photo.isNotEmpty) {
          profilePhotoUrl = ApiService.resolvePhotoUrl(photo);
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

      final success = result['success'] == true;
      if (success) {
        final newUrl = result['photo_url']?.toString();
        setState(() {
          if (newUrl != null && newUrl.isNotEmpty) {
            profilePhotoUrl = newUrl;
          }
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          success
              ? result['message'] ?? 'Foto profil berhasil diperbarui'
              : result['message'] ?? 'Gagal mengunggah foto profil',
        ),
        backgroundColor: success ? AppColors.success : AppColors.danger,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal memilih foto: $e'),
        backgroundColor: AppColors.danger,
      ));
    }
  }

  void _showPhotoSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.lg,
            horizontal: AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ubah Foto Profil Staff',
                style: AppTextStyles.title.copyWith(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _photoOptionTile(
                    icon: Icons.camera_alt_rounded,
                    label: 'Kamera',
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadPhoto(ImageSource.camera);
                    },
                  ),
                  _photoOptionTile(
                    icon: Icons.photo_library_rounded,
                    label: 'Galeri Foto',
                    color: AppColors.accent,
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUploadPhoto(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: AppSpacing.sm),
            Text(
              label,
              style: AppTextStyles.subheading.copyWith(color: color),
            ),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          isDark ? 'Mode Gelap Diaktifkan' : 'Mode Terang Diaktifkan',
        ),
      ));
    }
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
        title: const Text('Keluar Akun'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun CashMate?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ApiService.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              }
            },
            child: const Text('Keluar'),
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
        title: const Text('Profil Staff'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadStaffInfo,
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            // ---- Kartu Identitas & Foto Profil ----
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                children: [
                  Stack(
                    children: [
                      GestureDetector(
                        onTap: isUploading ? null : _showPhotoSourceBottomSheet,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.primary.lighten(0.3)
                                  : AppColors.primary,
                              width: 2.5,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 42,
                            backgroundColor: AppColors.primarySoft,
                            backgroundImage: (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty)
                                ? NetworkImage(profilePhotoUrl!)
                                : null,
                            child: isUploading
                                ? const CircularProgressIndicator(color: AppColors.primary)
                                : (profilePhotoUrl == null || profilePhotoUrl!.isEmpty)
                                    ? Text(
                                        staffName.isNotEmpty
                                            ? staffName[0].toUpperCase()
                                            : 'S',
                                        style: AppTextStyles.title.copyWith(
                                          color: AppColors.primary,
                                          fontSize: 32,
                                        ),
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
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    staffName.isNotEmpty ? staffName : 'Staff Kasir',
                    style: AppTextStyles.title.copyWith(
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    staffEmail,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      AppBadge(
                        label: userRole,
                        color: AppColors.primary,
                        icon: Icons.badge_outlined,
                      ),
                      if (businessName.isNotEmpty)
                        AppBadge(
                          label: businessName,
                          color: AppColors.accent,
                          icon: Icons.storefront_rounded,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: _showPhotoSourceBottomSheet,
                    icon: const Icon(Icons.edit, size: 14),
                    label: const Text('Ganti Foto Profil'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ---- Pengaturan Aplikasi ----
            AppSectionHeaderWrapper(
              title: 'Pengaturan Aplikasi',
              child: AppCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  secondary: AppIconBadgeBox(
                    icon: isDark ? Icons.dark_mode : Icons.light_mode,
                    color: AppColors.primary,
                  ),
                  title: Text(
                    'Mode Gelap',
                    style: AppTextStyles.subheading.copyWith(
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  subtitle: Text(
                    isDark ? 'Tema gelap aktif' : 'Tema terang aktif',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  value: isDark,
                  onChanged: _changeThemeMode,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ---- Petunjuk Kasir ----
            AppCard(
              padding: EdgeInsets.zero,
              onTap: () => _showGuideDialog(theme),
              child: ListTile(
                leading: AppIconBadgeBox(
                  icon: Icons.help_outline_rounded,
                  color: AppColors.info,
                ),
                title: Text(
                  'Panduan Staff / Kasir',
                  style: AppTextStyles.subheading.copyWith(
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                ),
                subtitle: Text(
                  'Cara mencatat transaksi & upload nota',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ---- Logout ----
            AppCard(
              padding: EdgeInsets.zero,
              color: AppColors.danger.withValues(alpha: 0.06),
              bordered: false,
              shadowed: false,
              onTap: _showLogoutConfirmation,
              child: ListTile(
                leading: AppIconBadgeBox(
                  icon: Icons.logout_rounded,
                  color: AppColors.danger,
                ),
                title: Text(
                  'Keluar Akun',
                  style: AppTextStyles.subheading.copyWith(color: AppColors.danger),
                ),
                subtitle: Text(
                  'Logout dari akun Staff CashMate',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            Center(
              child: Text(
                'CashMate Staff v1.0.0',
                style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGuideDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
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
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Mengerti'),
          ),
        ],
      ),
    );
  }
}

/// Helper mini untuk keep widget ringan tanpa harus mengimpor header stok.
class AppSectionHeaderWrapper extends StatelessWidget {
  final String title;
  final Widget child;

  const AppSectionHeaderWrapper({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.subheading.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

/// Kotak ikon kecil di dalam ListTile.
class AppIconBadgeBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const AppIconBadgeBox({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}