import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../add_transaction_page.dart';

/// Halaman Data Aktif Staff CashMate:
/// Menampilkan daftar Dompet Usaha Aktif (Cash, Bank, QRIS) dan Kategori Aktif (Pemasukan & Pengeluaran)
/// beserta aksi langsung untuk mencatat transaksi menggunakan dompet / kategori tersebut.
class StaffDataPage extends StatefulWidget {
  const StaffDataPage({super.key});

  @override
  State<StaffDataPage> createState() => _StaffDataPageState();
}

class _StaffDataPageState extends State<StaffDataPage> with SingleTickerProviderStateMixin {
  static const _blue = Color(0xFF0D6EFD);
  static const _amber = Color(0xFFFFB800);

  late TabController _tabController;
  List<Map<String, dynamic>> _wallets = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';

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

  String _formatRupiah(double amount) {
    String str = amount.toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String result = str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return 'Rp $result';
  }

  void _openAddTransaction() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionPage()),
    );
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
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_blue, _amber]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder_open_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(text: 'Cash', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _blue)),
                      TextSpan(text: 'Mate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _amber)),
                    ],
                  ),
                ),
                Text('Dompet & Kategori Usaha', style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _blue,
          labelColor: _blue,
          unselectedLabelColor: theme.hintColor,
          tabs: const [
            Tab(icon: Icon(Icons.account_balance_wallet_outlined, size: 18), text: 'Dompet Usaha'),
            Tab(icon: Icon(Icons.category_outlined, size: 18), text: 'Kategori'),
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
    final filtered = _wallets.where((w) {
      final name = (w['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        _buildSearchBox(theme, 'Cari nama dompet...'),
        Expanded(
          child: filtered.isEmpty
              ? _emptyState('Belum ada dompet aktif', Icons.savings_outlined, theme)
              : ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final w = filtered[index];
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _blue.withValues(alpha: 0.15)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined, color: _blue, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w['name'] ?? 'Dompet',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.textTheme.bodyLarge?.color),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _blue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(w['currency'] ?? 'IDR', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _blue)),
                              ),
                              const SizedBox(width: 8),
                              if (w['balance'] != null)
                                Text(
                                  _formatRupiah((w['balance'] is num) ? (w['balance'] as num).toDouble() : double.tryParse(w['balance'].toString()) ?? 0),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _blue),
                                )
                              else
                                const Text('Aktif untuk transaksi', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _openAddTransaction,
                      icon: const Icon(Icons.add, size: 14),
                      label: const Text('Catat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList(ThemeData theme) {
    final filtered = _categories.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    final income = filtered.where((c) => c['type'] == 'income').toList();
    final expense = filtered.where((c) => c['type'] == 'expense').toList();

    if (filtered.isEmpty) {
      return Column(
        children: [
          _buildSearchBox(theme, 'Cari nama kategori...'),
          Expanded(child: _emptyState('Belum ada kategori aktif', Icons.category_outlined, theme)),
        ],
      );
    }

    return Column(
      children: [
        _buildSearchBox(theme, 'Cari nama kategori...'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              if (income.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.arrow_downward_rounded, size: 16, color: _blue),
                    const SizedBox(width: 6),
                    Text('Pemasukan (${income.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _blue)),
                  ],
                ),
                const SizedBox(height: 8),
                ...income.map((c) => _categoryTile(c, _blue, theme)),
                const SizedBox(height: 16),
              ],
              if (expense.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.arrow_upward_rounded, size: 16, color: _amber),
                    const SizedBox(width: 6),
                    Text('Pengeluaran (${expense.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _amber)),
                  ],
                ),
                const SizedBox(height: 8),
                ...expense.map((c) => _categoryTile(c, _amber, theme)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryTile(Map<String, dynamic> c, Color color, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.12),
            child: Text(
              (c['name'] ?? '?')[0].toUpperCase(),
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(c['name'] ?? '-', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              c['type'] == 'income' ? 'Pemasukan' : 'Pengeluaran',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox(ThemeData theme, String hint) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search, size: 20),
          filled: true,
          fillColor: theme.cardColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.dividerColor.withValues(alpha: 0.2)),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String message, IconData icon, ThemeData theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: theme.hintColor),
              const SizedBox(height: 12),
              Text(message, style: TextStyle(color: theme.hintColor, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Tarik ke bawah (pull to refresh) untuk memperbarui data', style: TextStyle(fontSize: 10, color: theme.hintColor.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ],
    );
  }
}
