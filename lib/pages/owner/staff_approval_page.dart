import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Halaman Owner untuk mengelola Staff: melihat daftar (aktif/nonaktif/semua),
/// menambah Staff baru, menonaktifkan, dan memulihkan.
class StaffApprovalPage extends StatefulWidget {
  const StaffApprovalPage({super.key});

  @override
  State<StaffApprovalPage> createState() => _StaffApprovalPageState();
}

class _StaffApprovalPageState extends State<StaffApprovalPage> {
  static const _primaryBlue = Color(0xFF1155D9);

  List<Map<String, dynamic>> staffList = [];
  bool isLoading = true;
  final Set<int> _processingIds = {};

  // Filter status: active, disabled, all
  String _statusFilter = 'active';

  @override
  void initState() {
    super.initState();
    _loadStaffList();
  }

  Future<void> _loadStaffList() async {
    setState(() => isLoading = true);
    final result = await ApiService.fetchStaff(status: _statusFilter);
    if (!mounted) return;
    setState(() {
      staffList = result;
      isLoading = false;
    });
  }

  void _onStatusFilterChanged(String status) {
    if (_statusFilter == status) return;
    setState(() => _statusFilter = status);
    _loadStaffList();
  }

  // ---- Tambah Staff Baru ----
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
          title: const Text('Tambah Staff Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Masukkan data di bawah ini agar Staff dapat langsung login ke aplikasi menggunakan email & password.',
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
                  decoration: const InputDecoration(
                    labelText: 'Password (min. 8 karakter)',
                    prefixIcon: Icon(Icons.lock),
                  ),
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
              style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue),
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

                // API meminta minimal 8 karakter password
                if (password.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password minimal 8 karakter!')),
                  );
                  return;
                }

                setDialogState(() => isSaving = true);

                // POST /staff — buat Staff, bukan registerOwner
                final result = await ApiService.createStaff(
                  name: name,
                  email: email,
                  password: password,
                );

                setDialogState(() => isSaving = false);

                if (result['success'] == true) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Staff baru berhasil ditambahkan!')),
                  );
                  await _loadStaffList();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(result['message'] ?? 'Gagal menambahkan Staff.')),
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

  // ---- Nonaktifkan Staff (soft delete) ----
  Future<void> _handleDisableStaff(int staffId, String staffName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nonaktifkan Staff?'),
        content: Text('Staff "$staffName" akan dinonaktifkan dan tidak bisa login. Histori transaksi tetap tersimpan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Nonaktifkan', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _processingIds.add(staffId));
    final result = await ApiService.disableStaff(staffId);
    if (!mounted) return;

    setState(() => _processingIds.remove(staffId));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['success'] == true
            ? 'Staff berhasil dinonaktifkan.'
            : (result['message'] ?? 'Gagal menonaktifkan Staff.')),
      ),
    );
    if (result['success'] == true) await _loadStaffList();
  }

  // ---- Pulihkan Staff ----
  Future<void> _handleRestoreStaff(int staffId, String staffName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pulihkan Staff?'),
        content: Text('Staff "$staffName" akan diaktifkan kembali dan dapat login.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Pulihkan', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _processingIds.add(staffId));
    final result = await ApiService.restoreStaff(staffId);
    if (!mounted) return;

    setState(() => _processingIds.remove(staffId));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['success'] == true
            ? 'Staff berhasil dipulihkan.'
            : (result['message'] ?? 'Gagal memulihkan Staff.')),
      ),
    );
    if (result['success'] == true) await _loadStaffList();
  }

  bool _isStaffDisabled(Map<String, dynamic> staff) {
    final deletedAt = staff['deleted_at'];
    return deletedAt != null && deletedAt.toString().isNotEmpty && deletedAt.toString() != 'null';
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
          'Manajemen Staff',
          style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStaffDialog,
        backgroundColor: _primaryBlue,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Tambah Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadStaffList,
        child: Column(
          children: [
            // ---- Status filter chips ----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  _filterChip('Aktif', 'active', theme),
                  const SizedBox(width: 8),
                  _filterChip('Nonaktif', 'disabled', theme),
                  const SizedBox(width: 8),
                  _filterChip('Semua', 'all', theme),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ---- Content ----
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : staffList.isEmpty
                  ? ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.group_outlined, size: 48, color: theme.hintColor),
                        const SizedBox(height: 12),
                        Text(
                          _statusFilter == 'active'
                              ? 'Belum ada Staff aktif'
                              : _statusFilter == 'disabled'
                              ? 'Tidak ada Staff nonaktif'
                              : 'Belum ada Staff terdaftar',
                          style: TextStyle(color: theme.hintColor, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Ketuk tombol "Tambah Staff" untuk mendaftarkan Staff baru.',
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
                  return _buildStaffTile(staff, theme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, String value, ThemeData theme) {
    final selected = _statusFilter == value;
    return GestureDetector(
      onTap: () => _onStatusFilterChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _primaryBlue : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _primaryBlue : theme.dividerColor.withOpacity(0.2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : theme.textTheme.bodyLarge?.color,
          ),
        ),
      ),
    );
  }

  Widget _buildStaffTile(Map<String, dynamic> staff, ThemeData theme) {
    final int staffId = staff['id'];
    final String staffName = staff['name'] ?? '-';
    final bool isProcessing = _processingIds.contains(staffId);
    final bool isDisabled = _isStaffDisabled(staff);

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
            backgroundColor: isDisabled
                ? Colors.grey.withOpacity(0.15)
                : _primaryBlue.withOpacity(0.15),
            child: Icon(
              Icons.person,
              color: isDisabled ? Colors.grey : _primaryBlue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        staffName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isDisabled ? theme.hintColor : theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    if (isDisabled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'NONAKTIF',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  staff['email'] ?? '-',
                  style: TextStyle(fontSize: 12, color: theme.hintColor),
                ),
              ],
            ),
          ),
          if (isProcessing)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else if (isDisabled)
            IconButton(
              icon: const Icon(Icons.restore, color: Colors.green),
              onPressed: () => _handleRestoreStaff(staffId, staffName),
              tooltip: 'Pulihkan Staff',
            )
          else
            IconButton(
              icon: const Icon(Icons.person_off_outlined, color: Colors.orange),
              onPressed: () => _handleDisableStaff(staffId, staffName),
              tooltip: 'Nonaktifkan Staff',
            ),
        ],
      ),
    );
  }
}