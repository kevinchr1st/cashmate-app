import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Halaman kelola Kategori (Income & Expense).
/// Mengikuti Postman collection "CashMate API MVP" -> 02 Owner Setup & 06 Owner Resource Lifecycle:
///   POST   /categories                -> buat kategori baru
///   GET    /categories?status=active  -> daftar kategori aktif
///   GET    /categories?status=disabled-> daftar kategori nonaktif
///   DELETE /categories/{id}           -> nonaktifkan kategori (soft delete)
///   POST   /categories/{id}/restore   -> aktifkan kembali kategori
///
/// Catatan: backend belum menyediakan endpoint update/edit kategori di Postman
/// collection ini, jadi halaman ini hanya menyediakan Buat, Nonaktifkan, dan
/// Pulihkan kategori.
class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final nameController = TextEditingController();
  String selectedType = 'income';

  bool isLoadingActive = true;
  bool isLoadingDisabled = true;
  bool isSaving = false;

  List<Map<String, dynamic>> activeCategories = [];
  List<Map<String, dynamic>> disabledCategories = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchActiveCategories();
    _fetchDisabledCategories();
  }

  @override
  void dispose() {
    _tabController.dispose();
    nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchActiveCategories() async {
    setState(() => isLoadingActive = true);
    final data = await ApiService.fetchCategories(status: 'active');
    if (!mounted) return;
    setState(() {
      activeCategories = data;
      isLoadingActive = false;
    });
  }

  Future<void> _fetchDisabledCategories() async {
    setState(() => isLoadingDisabled = true);
    final data = await ApiService.fetchCategories(status: 'disabled');
    if (!mounted) return;
    setState(() {
      disabledCategories = data;
      isLoadingDisabled = false;
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([_fetchActiveCategories(), _fetchDisabledCategories()]);
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _createCategory(StateSetter setModalState) async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Nama kategori tidak boleh kosong!', isError: true);
      return;
    }

    setModalState(() => isSaving = true);
    final result = await ApiService.createCategory(name: name, type: selectedType);
    setModalState(() => isSaving = false);

    if (result['success'] == true) {
      nameController.clear();
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
      _showSnack(result['message'] ?? 'Kategori berhasil dibuat');
      await _fetchActiveCategories();
    } else {
      _showSnack(result['message'] ?? 'Gagal membuat kategori', isError: true);
    }
  }

  Future<void> _disableCategory(Map<String, dynamic> category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nonaktifkan Kategori'),
        content: Text('Nonaktifkan kategori "${category['name']}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Nonaktifkan', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final id = int.tryParse(category['id'].toString());
    if (id == null) return;

    final ok = await ApiService.disableCategory(id);
    if (ok) {
      _showSnack('Kategori berhasil dinonaktifkan');
      await _refreshAll();
    } else {
      _showSnack('Gagal menonaktifkan kategori', isError: true);
    }
  }

  Future<void> _restoreCategory(Map<String, dynamic> category) async {
    final id = int.tryParse(category['id'].toString());
    if (id == null) return;

    final ok = await ApiService.restoreCategory(id);
    if (ok) {
      _showSnack('Kategori berhasil dipulihkan');
      await _refreshAll();
    } else {
      _showSnack('Gagal memulihkan kategori', isError: true);
    }
  }

  void _showAddCategoryModal() {
    nameController.clear();
    setState(() => selectedType = 'income');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kategori Baru',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(modalContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kategori',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Tipe',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'income', child: Text('Income (Pemasukan)')),
                      DropdownMenuItem(value: 'expense', child: Text('Expense (Pengeluaran)')),
                    ],
                    onChanged: (val) {
                      setModalState(() => selectedType = val!);
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0052CC),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSaving ? null : () => _createCategory(setModalState),
                    child: isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Simpan Kategori',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> category, {required bool isActive}) {
    final bool isIncome = category['type'] == 'income';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            isIncome ? Icons.arrow_downward : Icons.arrow_upward,
            color: isIncome ? Colors.green : Colors.red,
          ),
        ),
        title: Text(
          category['name'] ?? 'Tanpa Nama',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(isIncome ? 'Income' : 'Expense'),
        trailing: isActive
            ? IconButton(
                icon: const Icon(Icons.block, color: Colors.red),
                tooltip: 'Nonaktifkan',
                onPressed: () => _disableCategory(category),
              )
            : IconButton(
                icon: const Icon(Icons.restore, color: Colors.green),
                tooltip: 'Pulihkan',
                onPressed: () => _restoreCategory(category),
              ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, bool isLoading, {required bool isActive}) {
    if (isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
    }
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(isActive ? 'Belum ada kategori aktif' : 'Tidak ada kategori nonaktif'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (context, index) => _buildCategoryTile(items[index], isActive: isActive),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Aktif'),
            Tab(text: 'Nonaktif'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0052CC),
        onPressed: _showAddCategoryModal,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(activeCategories, isLoadingActive, isActive: true),
          _buildList(disabledCategories, isLoadingDisabled, isActive: false),
        ],
      ),
    );
  }
}
