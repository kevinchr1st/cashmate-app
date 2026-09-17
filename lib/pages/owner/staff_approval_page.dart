import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Halaman khusus Owner untuk Mengelola & Menambahkan Staff baru
/// dengan memasukkan Nama, Email, dan Password sementara.
class StaffApprovalPage extends StatefulWidget {
  const StaffApprovalPage({super.key});

  @override
  State<StaffApprovalPage> createState() => _StaffApprovalPageState();
}

class _StaffApprovalPageState extends State<StaffApprovalPage> {
  List<Map<String, dynamic>> staffList = [];
  bool isLoading = true;
  final Set<int> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _loadStaffList();
  }

  Future<void> _loadStaffList() async {
    setState(() => isLoading = true);
    // Mengambil daftar staff atau staff pending dari API service
    final result = await ApiService.fetchPendingStaff();
    if (!mounted) return;
    setState(() {
      staffList = result;
      isLoading = false;
    });
  }

  // Dialog untuk Menambahkan Staff Baru (Nama, Email, Password Sementara)
  void _showAddStaffDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah Staff / Kasir Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Masukkan data di bawah ini agar staff dapat langsung login ke aplikasi menggunakan email & password sementara.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap Staff', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Alamat Email', prefixIcon: Icon(Icons.email)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password Sementara', prefixIcon: Icon(Icons.lock)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1155D9)),
              onPressed: isSaving
                  ? null
                  : () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                final password = passwordController.text.trim();

                if (name.isEmpty || email.isEmpty || password.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Semua kolom wajib diisi!')),
                  );
                  return;
                }

                if (password.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password minimal 6 karakter!')),
                  );
                  return;
                }

                setDialogState(() => isSaving = true);

                // Memanggil API untuk mendaftarkan staff baru
                final result = await ApiService.registerOwner(
                  name: name,
                  email: email,
                  password: password,
                  businessName: 'Staff Account',
                );

                setDialogState(() => isSaving = false);

                if (result['success'] == true || result['token'] != null) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Staff baru berhasil ditambahkan!')),
                  );
                  await _loadStaffList();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'] ?? 'Gagal menambahkan staff.')),
                  );
                }
              },
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Simpan & Tambah', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteStaff(int staffId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Akses Staff?'),
        content: const Text('Akun staff ini akan dihapus permanen dari sistem toko.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _processingIds.add(staffId));
    final success = await ApiService.rejectStaff(staffId);
    if (!mounted) return;

    setState(() {
      staffList.removeWhere((s) => s['id'] == staffId);
      _processingIds.remove(staffId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Akses staff berhasil dihapus.' : 'Gagal menghapus staff.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textTheme.bodyLarge?.color),
        title: Text(
          'Manajemen & Tambah Staff',
          style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStaffDialog,
        backgroundColor: const Color(0xFF1155D9),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Tambah Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStaffList,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : staffList.isEmpty
            ? ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.3),
            Center(
              child: Column(
                children: [
                  Icon(Icons.group_outlined, size: 48, color: theme.hintColor),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada staff terdaftar',
                    style: TextStyle(color: theme.hintColor, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ketuk tombol "Tambah Staff" di bawah untuk mendaftarkan kasir.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        )
            : ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: staffList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final staff = staffList[index];
            final int staffId = staff['id'];
            final bool isProcessing = _processingIds.contains(staffId);

            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF1155D9).withOpacity(0.15),
                    child: const Icon(Icons.person, color: Color(0xFF1155D9)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff['name'] ?? '-',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyLarge?.color),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          staff['email'] ?? '-',
                          style: TextStyle(fontSize: 12, color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  isProcessing
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _handleDeleteStaff(staffId),
                    tooltip: 'Hapus Akses',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}