import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/api_service.dart';
import '../../main.dart';
import 'staff_approval_page.dart';
import 'category_page.dart';

class ProfilePage extends StatefulWidget {
  final int? userId;
  const ProfilePage({super.key, this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? userData;
  bool isLoading = true;
  bool isOwner = true;

  File? _imageFile;
  String? _profilePhotoUrl;
  bool _isUploadingPhoto = false;
  final ImagePicker _picker = ImagePicker();
  final LocalAuthentication _localAuth = LocalAuthentication();

  String ownerName = 'Gigih Erlangga';
  String storeName = 'Toko Makmur Jaya';
  String storeCode = 'CM-0929-JKT';
  String businessCategory = 'Retail & F&B';
  String address = 'Jl. Melati No. 12, Jakarta';
  String phoneNumber = '0812-3456-7890';
  String bankAccount = 'BCA **** 4491 • A.N. Gigih Erlangga';
  bool isBiometricEnabled = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadProfileData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    setState(() => isLoading = true);
    try {
      final roleStatus = await ApiService.isOwner();
      isOwner = roleStatus;

      final prefs = await SharedPreferences.getInstance();
      ownerName = prefs.getString('saved_owner_name') ?? ownerName;
      storeName = prefs.getString('saved_store_name') ?? storeName;
      phoneNumber = prefs.getString('saved_phone') ?? phoneNumber;
      address = prefs.getString('saved_address') ?? address;
      bankAccount = prefs.getString('saved_bank_account') ?? bankAccount;
      isBiometricEnabled = prefs.getBool('is_biometric_enabled') ?? true;

      // Foto profil yang tersimpan (path relatif dari server, hasil upload sebelumnya)
      final savedPhotoPath = prefs.getString('saved_profile_photo_path');
      if (savedPhotoPath != null && savedPhotoPath.isNotEmpty) {
        _profilePhotoUrl = ApiService.resolvePhotoUrl(savedPhotoPath);
      }

      final data = await ApiService.fetchProfile().timeout(const Duration(seconds: 5));
      if (data != null) {
        userData = data;
        if (data['name'] != null) ownerName = data['name'];
        if (data['store_name'] != null) storeName = data['store_name'];
      }

      // Sinkronkan foto profil terbaru dari server (GET /auth/me)
      final me = await ApiService.getCurrentUser();
      final meUser = me != null ? me['user'] : null;
      if (meUser is Map && meUser['profile_photo'] != null && meUser['profile_photo'].toString().isNotEmpty) {
        _profilePhotoUrl = ApiService.resolvePhotoUrl(meUser['profile_photo'].toString());
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

      // Tampilkan preview lokal langsung sambil menunggu upload selesai
      setState(() {
        _imageFile = imageFile;
        _isUploadingPhoto = true;
      });

      // PUT {{base_url}}/auth/me/photo (multipart, field "photo")
      final result = await ApiService.uploadProfilePhoto(imageFile);

      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _profilePhotoUrl = result['photo_url'] as String?;
          _isUploadingPhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Foto profil berhasil diunggah & disimpan di server!')),
        );
      } else {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Gagal mengunggah foto ke server')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengambil foto: $e')));
      }
    }
  }

  void _showEditProfileDialog() {
    final nameCtrl = TextEditingController(text: ownerName);
    final storeCtrl = TextEditingController(text: storeName);
    final addressCtrl = TextEditingController(text: address);
    final phoneCtrl = TextEditingController(text: phoneNumber);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Informasi Usaha & Toko', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Pemilik', prefixIcon: Icon(Icons.person))),
              const SizedBox(height: 8),
              TextField(controller: storeCtrl, decoration: const InputDecoration(labelText: 'Nama Toko', prefixIcon: Icon(Icons.storefront))),
              const SizedBox(height: 8),
              TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Lokasi / Alamat', prefixIcon: Icon(Icons.location_on))),
              const SizedBox(height: 8),
              TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No. Telepon', prefixIcon: Icon(Icons.phone))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1155D9)),
            onPressed: () async {
              Navigator.pop(context);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('saved_owner_name', nameCtrl.text.trim());
              await prefs.setString('saved_store_name', storeCtrl.text.trim());
              await prefs.setString('saved_address', addressCtrl.text.trim());
              await prefs.setString('saved_phone', phoneCtrl.text.trim());

              setState(() {
                ownerName = nameCtrl.text.trim();
                storeName = storeCtrl.text.trim();
                address = addressCtrl.text.trim();
                phoneNumber = phoneCtrl.text.trim();
              });

              await ApiService.updateProfile({
                'name': ownerName,
                'store_name': storeName,
                'address': address,
                'phone': phoneNumber,
              });

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil berhasil disimpan!')));
              }
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari akun CashMate UMKM?'),
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFF1155D9), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PENGATURAN & TOKO', style: TextStyle(color: theme.hintColor, fontSize: 10, fontWeight: FontWeight.bold)),
                Text('Toko & Profil Saya', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: theme.iconTheme.color),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada pemberitahuan baru.'))),
          ),
          IconButton(
            icon: Icon(Icons.help_outline, color: theme.iconTheme.color),
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pusat Bantuan CashMate aktif 24/7.'))),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          child: isOwner ? _buildOwnerView(theme) : _buildStaffView(theme),
        ),
      ),
    );
  }

  Widget _buildOwnerView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Kartu Identitas Utama
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: theme.dividerColor.withOpacity(0.2),
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!) as ImageProvider
                            : (_profilePhotoUrl != null
                            ? NetworkImage(_profilePhotoUrl!) as ImageProvider
                            : const NetworkImage('https://i.pravatar.cc/300') as ImageProvider),
                        child: _isUploadingPhoto
                            ? const CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.black45,
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        )
                            : null,
                      ),
                      InkWell(
                        onTap: _isUploadingPhoto ? null : _pickAndUploadProfilePhoto,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Color(0xFF1155D9), shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(ownerName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                              child: Row(
                                children: const [
                                  Icon(Icons.check, size: 10, color: Colors.green),
                                  SizedBox(width: 2),
                                  Text('Terverifikasi', style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text('gigih@gmail.com • $phoneNumber', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFF1155D9).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                              child: const Text('OWNER (Akses Penuh)', style: TextStyle(fontSize: 10, color: Color(0xFF1155D9), fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            Text('Shift: Aktif', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: theme.dividerColor.withOpacity(0.2))),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark ? Colors.black26 : const Color(0xFFF7F8FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('NAMA USAHA / TOKO', style: TextStyle(fontSize: 9, color: theme.hintColor, fontWeight: FontWeight.bold)),
                        InkWell(
                          onTap: _showEditProfileDialog,
                          child: const Text('Edit >', style: TextStyle(fontSize: 11, color: Color(0xFF1155D9), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(storeName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(storeCode, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.hintColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: Text('Kategori Usaha:\n$businessCategory', style: TextStyle(fontSize: 11, color: theme.hintColor))),
                        Expanded(child: Text('Lokasi:\n$address', style: TextStyle(fontSize: 11, color: theme.hintColor))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Tab Navigasi Kategori Pengaturan
        Container(
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
          child: TabBar(
            controller: _tabController,
            labelColor: const Color(0xFF1155D9),
            unselectedLabelColor: theme.hintColor,
            indicatorColor: const Color(0xFF1155D9),
            tabs: const [
              Tab(text: 'Informasi'),
              Tab(text: 'Toko & POS'),
              Tab(text: 'Keamanan'),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Konten Tab Berdasarkan TabController
        SizedBox(
          height: 420,
          child: TabBarView(
            controller: _tabController,
            children: [
              // --- TAB 1: INFORMASI AKUN & RBAC ---
              SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.admin_panel_settings_outlined, color: Color(0xFF1155D9), size: 18),
                                  const SizedBox(width: 8),
                                  Text('AKSES STAF & KASIR (RBAC)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                child: const Text('FR-07', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Batas wewenang pencatatan & void transaksi', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                          const SizedBox(height: 12),
                          // Kotak Informasi Staf / Kasir (Real Data)
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: ApiService.fetchPendingStaff(),
                            builder: (context, snapshot) {
                              final staffList = snapshot.data ?? [];

                              if (staffList.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: theme.brightness == Brightness.dark ? Colors.black26 : const Color(0xFFF7F8FC),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Belum ada staff tambahan terkelola. Ketuk tombol di bawah untuk menambah.',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                );
                              }

                              return ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: staffList.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final staff = staffList[index];
                                  final staffName = staff['name'] ?? 'Staff CashMate';
                                  final staffEmail = staff['email'] ?? '';

                                  return Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: theme.brightness == Brightness.dark ? Colors.black26 : const Color(0xFFF7F8FC),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: theme.dividerColor.withOpacity(0.3),
                                          child: Text(
                                            staffName.isNotEmpty ? staffName[0].toUpperCase() : 'S',
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(staffName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                                              Text(staffEmail, style: TextStyle(fontSize: 10, color: theme.hintColor)),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                          child: const Text('Aktif', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1155D9),
                                side: const BorderSide(color: Color(0xFF1155D9)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffApprovalPage())),
                              icon: const Icon(Icons.group_outlined, size: 16),
                              label: const Text('Kelola Hak Akses Staf Kasir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- TAB 2: TOKO & POS (Metode Pembayaran & Operasional) ---
              SingleChildScrollView(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('METODE & BANK TERHUBUNG', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                              TextButton(
                                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fitur tambah rekening baru.'))),
                                child: const Text('Tambah Rekening', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1155D9))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildBankTile('QRIS', 'QRIS Merchant GPN', 'NMID: ID10200392019 • Auto settlement', 'Aktif', Colors.red, theme),
                          const SizedBox(height: 8),
                          _buildBankTile('BCA', 'Bank Central Asia (BCA)', bankAccount, 'Utama', Colors.blue, theme),
                          const SizedBox(height: 16),
                          Text('PREFERENSI OPERASIONAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                          const SizedBox(height: 8),
                          _buildPreferenceTile(
                            icon: Icons.category_outlined,
                            title: 'Kategori & Kantong Kas Toko',
                            subtitle: 'Atur Kategori & alokasi modal',
                            theme: theme,
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoryPage())),
                          ),
                          _buildPreferenceTile(
                            icon: Icons.print_outlined,
                            title: 'Printer Thermal & Format Nota',
                            subtitle: 'Bluetooth 58mm/80mm • Header struk',
                            badge: 'Tersambung',
                            theme: theme,
                          ),
                          _buildPreferenceTile(
                            icon: Icons.cloud_sync_outlined,
                            title: 'Sinkronisasi Cloud & Audit FR-07',
                            subtitle: 'Backup otomatis setiap penutupan shift',
                            badgeColor: Colors.green,
                            theme: theme,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- TAB 3: KEAMANAN & TAMPILAN (PIN, Biometrik, Dark/Light Mode) ---
              SingleChildScrollView(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PENGATURAN KEAMANAN & TAMPILAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                      const SizedBox(height: 10),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.fingerprint, color: Color(0xFF1155D9)),
                        title: Text('Autentikasi Biometrik & PIN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                        subtitle: Text('Verifikasi saat void & refund dana', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                        trailing: Switch(
                          value: isBiometricEnabled,
                          activeColor: const Color(0xFF1155D9),
                          onChanged: _handleBiometricToggle,
                        ),
                      ),
                      const Divider(height: 20),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          themeNotifier.value == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                          color: const Color(0xFF1155D9),
                        ),
                        title: Text('Mode Tampilan (Theme)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                        subtitle: Text(
                          themeNotifier.value == ThemeMode.dark ? 'Mode Gelap Aktif' : 'Mode Terang Aktif',
                          style: TextStyle(fontSize: 11, color: theme.hintColor),
                        ),
                        trailing: Switch(
                          value: themeNotifier.value == ThemeMode.dark,
                          activeColor: const Color(0xFF1155D9),
                          onChanged: (isDark) => _changeThemeMode(isDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Tombol Keluar
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.brightness == Brightness.dark ? Colors.red.shade900.withOpacity(0.3) : const Color(0xFFFCE8E6),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _showLogoutConfirmation,
            icon: const Icon(Icons.logout, color: Colors.red, size: 16),
            label: const Text('Keluar dari Akun (Logout)', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
        ),

        const SizedBox(height: 12),
        Center(
          child: Text('CashMate App v2.4.1 (Build 2026.09) • Lindungi PIN Toko Anda', style: TextStyle(fontSize: 10, color: theme.hintColor)),
        ),
      ],
    );
  }

  Widget _buildStaffView(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue.shade100,
                child: const Icon(Icons.person, size: 30, color: Color(0xFF1155D9)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ownerName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                    const Text('Staff / Kasir Aktif', style: TextStyle(fontSize: 11, color: Color(0xFF1155D9), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('Toko: $storeName', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KEAMANAN & TAMPILAN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: theme.hintColor)),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.fingerprint, color: Color(0xFF1155D9)),
                title: Text('Autentikasi Biometrik', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                subtitle: Text('Gunakan sidik jari untuk masuk', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                trailing: Switch(
                  value: isBiometricEnabled,
                  activeColor: const Color(0xFF1155D9),
                  onChanged: _handleBiometricToggle,
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(themeNotifier.value == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFF1155D9)),
                title: Text('Mode Tampilan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                subtitle: Text(themeNotifier.value == ThemeMode.dark ? 'Mode Gelap' : 'Mode Terang', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                trailing: Switch(
                  value: themeNotifier.value == ThemeMode.dark,
                  activeColor: const Color(0xFF1155D9),
                  onChanged: (isDark) => _changeThemeMode(isDark),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: theme.brightness == Brightness.dark ? Colors.red.shade900.withOpacity(0.3) : const Color(0xFFFCE8E6), elevation: 0),
            onPressed: _showLogoutConfirmation,
            icon: const Icon(Icons.logout, color: Colors.red, size: 16),
            label: const Text('Keluar dari Akun', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildBankTile(String code, String name, String subtitle, String tag, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? Colors.black26 : const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
            child: Text(code, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                Text(subtitle, style: TextStyle(fontSize: 10, color: theme.hintColor)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: tag == 'Utama' ? Colors.blue.withOpacity(0.15) : Colors.green.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(tag, style: TextStyle(fontSize: 10, color: tag == 'Utama' ? Colors.blue : Colors.green, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferenceTile({required IconData icon, required String title, required String subtitle, String? badge, Color badgeColor = Colors.grey, required ThemeData theme, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFF1155D9).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFF1155D9), size: 18),
      ),
      title: Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 10, color: theme.hintColor)),
      trailing: badge != null
          ? Text(badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor))
          : Icon(Icons.chevron_right, size: 18, color: theme.hintColor),
    );
  }

  Future<void> _handleBiometricToggle(bool val) async {
    if (val) {
      try {
        bool canCheck = await _localAuth.canCheckBiometrics;
        if (!canCheck) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perangkat tidak mendukung biometrik.')));
          return;
        }
      } catch (_) {}
    }
    setState(() => isBiometricEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_biometric_enabled', val);
  }
}