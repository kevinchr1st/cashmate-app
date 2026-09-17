import 'package:flutter/material.dart';

import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../add_transaction_page.dart';
import '../../services/api_service.dart';

/// Halaman Data Aktif Staff CashMate:
/// daftar Dompet Usaha Aktif dan Kategori Aktif (Pemasukan & Pengeluaran)
/// beserta aksi langsung mencatat transaksi.
class StaffDataPage extends StatefulWidget {
  const StaffDataPage({super.key});

  @override
  State<StaffDataPage> createState() => _StaffDataPageState();
}

class _StaffDataPageState extends State<StaffDataPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _wallets = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // RBAC: nominal saldo dompet hanya boleh dilihat Owner.
  bool canViewBalance = false;

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
    final role = await ApiService.currentRole();
    final wallets = await ApiService.fetchWallets(status: 'active');
    final categories = await ApiService.fetchCategories(status: 'active');
    if (!mounted) return;
    setState(() {
      canViewBalance = role == 'OWNER';
      _wallets = wallets;
      _categories = categories;
      _isLoading = false;
    });
  }

  static double _amountOf(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
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
        title: const Text('Data Toko'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: theme.hintColor,
          tabs: const [
            Tab(
                icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                text: 'Dompet Usaha'),
            Tab(
                icon: Icon(Icons.category_outlined, size: 18),
                text: 'Kategori'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadData,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWalletList(),
                  _buildCategoryList(),
                ],
              ),
            ),
    );
  }

  // ------------------------------------------------------------ dompet -------

  Widget _buildWalletList() {
    final theme = Theme.of(context);
    final filtered = _wallets.where((w) {
      final name = (w['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        _buildSearchBox('Cari nama dompet...'),
        Expanded(
          child: filtered.isEmpty
              ? const AppEmptyState(
                  icon: Icons.savings_outlined,
                  title: 'Belum ada dompet aktif',
                )
              : ListView.separated(
                  padding: AppSpacing.pagePadding.copyWith(top: AppSpacing.sm),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, index) {
                    final w = filtered[index];
                    return AppCard(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          AppIconBadge(
                            icon: Icons.account_balance_wallet_outlined,
                            color: AppColors.primary,
                            size: 40,
                            iconSize: 20,
                            radius: AppRadius.md,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  w['name']?.toString() ?? 'Dompet',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.subheading.copyWith(
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                if (canViewBalance)
                                  Text(
                                    Rupiah.format(_amountOf(w['balance'])),
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  )
                                else
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.visibility_off_outlined,
                                        size: 13,
                                        color: theme.hintColor,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Saldo tersembunyi',
                                        style: AppTextStyles.caption.copyWith(
                                          color: theme.hintColor,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ElevatedButton.icon(
                            onPressed: _openAddTransaction,
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Catat'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 36),
                              textStyle: AppTextStyles.subheading
                                  .copyWith(color: Colors.white),
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

  // --------------------------------------------------------- kategori -------

  Widget _buildCategoryList() {
    final filtered = _categories.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    final income = filtered.where((c) => c['type'] == 'income').toList();
    final expense = filtered.where((c) => c['type'] == 'expense').toList();

    if (filtered.isEmpty) {
      return Column(
        children: [
          _buildSearchBox('Cari nama kategori...'),
          const Expanded(
            child: AppEmptyState(
              icon: Icons.category_outlined,
              title: 'Belum ada kategori aktif',
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _buildSearchBox('Cari nama kategori...'),
        Expanded(
          child: ListView(
            padding: AppSpacing.pagePadding.copyWith(top: AppSpacing.sm),
            children: [
              if (income.isNotEmpty) ...[
                _sectionHeader('Pemasukan', income.length, AppColors.success),
                const SizedBox(height: AppSpacing.sm),
                ...income.map((c) => _categoryTile(c, AppColors.success)),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (expense.isNotEmpty) ...[
                _sectionHeader('Pengeluaran', expense.length, AppColors.danger),
                const SizedBox(height: AppSpacing.sm),
                ...expense.map((c) => _categoryTile(c, AppColors.danger)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, int count, Color color) {
    return Row(
      children: [
        Icon(
          title == 'Pemasukan'
              ? Icons.south_west_rounded
              : Icons.north_east_rounded,
          size: 16,
          color: color,
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$title ($count)',
          style: AppTextStyles.subheading.copyWith(color: color),
        ),
      ],
    );
  }

  Widget _categoryTile(Map<String, dynamic> c, Color color) {
    final theme = Theme.of(context);
    final label = c['type'] == 'income' ? 'Pemasukan' : 'Pengeluaran';

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Row(
        children: [
          AppIconBadge(
            icon: Icons.category_rounded,
            color: color,
            size: 34,
            iconSize: 16,
            radius: AppRadius.sm,
          ),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              c['name']?.toString() ?? '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.subheading.copyWith(
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ),
          AppBadge(
            label: label,
            color: color,
            icon: null,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------- bersama -------

  Widget _buildSearchBox(String hint) {
    return Padding(
      padding: AppSpacing.pagePadding.copyWith(bottom: AppSpacing.sm),
      child: TextField(
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
        ),
      ),
    );
  }
}
