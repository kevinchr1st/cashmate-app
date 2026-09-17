import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Halaman Staff: daftar wallet aktif (tanpa saldo) dan kategori aktif.
/// Read-only, untuk referensi saat form transaksi.
class StaffDataPage extends StatefulWidget {
  const StaffDataPage({super.key});

  @override
  State<StaffDataPage> createState() => _StaffDataPageState();
}

class _StaffDataPageState extends State<StaffDataPage> with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF0D6EFD);

  late TabController _tabController;
  List<Map<String, dynamic>> _wallets = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final wallets = await ApiService.fetchWallets(status: 'active');
    final categories = await ApiService.fetchCategories(status: 'active');
    if (!mounted) return;
    setState(() {
      _wallets = wallets;
      _categories = categories;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
              child: const Icon(Icons.folder_open, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Text('Data Aktif', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _blue,
          labelColor: _blue,
          unselectedLabelColor: theme.hintColor,
          tabs: const [
            Tab(text: 'Wallet'),
            Tab(text: 'Kategori'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildWalletList(theme),
            _buildCategoryList(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletList(ThemeData theme) {
    if (_wallets.isEmpty) {
      return _emptyState('Belum ada wallet aktif', Icons.savings_outlined, theme);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _wallets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final w = _wallets[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _blue.withOpacity(0.1),
                child: const Icon(Icons.savings_outlined, color: _blue, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(w['name'] ?? '-', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: theme.textTheme.bodyLarge?.color)),
                    Text(w['currency'] ?? 'IDR', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                  ],
                ),
              ),
              // Staff tidak melihat saldo
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryList(ThemeData theme) {
    if (_categories.isEmpty) {
      return _emptyState('Belum ada kategori aktif', Icons.category_outlined, theme);
    }

    final income = _categories.where((c) => c['type'] == 'income').toList();
    final expense = _categories.where((c) => c['type'] == 'expense').toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (income.isNotEmpty) ...[
          Text('Pemasukan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.hintColor)),
          const SizedBox(height: 8),
          ...income.map((c) => _categoryTile(c, Colors.green, theme)),
          const SizedBox(height: 16),
        ],
        if (expense.isNotEmpty) ...[
          Text('Pengeluaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.hintColor)),
          const SizedBox(height: 8),
          ...expense.map((c) => _categoryTile(c, Colors.red, theme)),
        ],
      ],
    );
  }

  Widget _categoryTile(Map<String, dynamic> c, Color color, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withOpacity(0.1),
            child: Text(
              (c['name'] ?? '?')[0].toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(c['name'] ?? '-', style: TextStyle(fontSize: 13.5, color: theme.textTheme.bodyLarge?.color)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              c['type'] == 'income' ? 'Pemasukan' : 'Pengeluaran',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String message, IconData icon, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: theme.hintColor),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: theme.hintColor, fontSize: 13)),
        ],
      ),
    );
  }
}
