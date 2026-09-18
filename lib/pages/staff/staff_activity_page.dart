import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/string_utils.dart';
import '../../widgets/app_badge.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/transaction_tile.dart';
import 'staff_home_page.dart';

/// Daftar transaksi Staff hari ini dengan filter pemasukan/pengeluaran
/// dan modal detail transaksi (termasuk foto nota).
class StaffActivityPage extends StatefulWidget {
  const StaffActivityPage({super.key});

  @override
  State<StaffActivityPage> createState() => _StaffActivityPageState();
}

class _StaffActivityPageState extends State<StaffActivityPage> {
  List<Map<String, dynamic>> _allTransactions = [];
  bool _isLoading = true;
  String _selectedFilter = 'semua'; // 'semua', 'income', 'expense'

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
    staffRefreshNotifier.addListener(_fetchTransactions);
  }

  @override
  void dispose() {
    staffRefreshNotifier.removeListener(_fetchTransactions);
    super.dispose();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    final result = await ApiService.fetchTransactions(perPage: 100);
    if (!mounted) return;
    setState(() {
      final list = result['data'] as List<dynamic>? ?? [];
      _allTransactions = list.map((e) => Map<String, dynamic>.from(e)).toList();
      _isLoading = false;
    });
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    return _allTransactions.where((t) {
      final type = (t['type']?.toString().toLowerCase() ?? '');
      if (_selectedFilter == 'income') return type == 'income';
      if (_selectedFilter == 'expense') return type == 'expense';
      return true;
    }).toList();
  }

  double get _totalIncome => _allTransactions
      .where((t) => (t['type']?.toString().toLowerCase() ?? '') == 'income')
      .fold(0.0, (sum, t) => sum + _parseAmount(t['amount']));

  double get _totalExpense => _allTransactions
      .where((t) => (t['type']?.toString().toLowerCase() ?? '') == 'expense')
      .fold(0.0, (sum, t) => sum + _parseAmount(t['amount']));

  static double _parseAmount(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} WIB';
  }

  void _showDetailModal(Map<String, dynamic> trx) {
    final type = (trx['type'] ?? '').toString();
    final isIncome = type == 'income';
    final desc = htmlUnescape((trx['description'] ?? '').toString());
    final amount = _parseAmount(trx['amount']);

    final walletName =
        trx['wallet'] is Map ? (trx['wallet']['name']?.toString() ?? 'Cash') : 'Cash';
    final categoryName =
        trx['category'] is Map ? (trx['category']['name']?.toString() ?? 'Umum') : 'Umum';
    final photos = trx['photos'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (dialogCtx) {
        final theme = Theme.of(context);
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.hintColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    AppIconBadge(
                      icon: isIncome
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      color: isIncome ? AppColors.success : AppColors.danger,
                      size: 44,
                      iconSize: 22,
                      radius: AppRadius.md,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isIncome ? 'Pemasukan Kasir' : 'Pengeluaran Kasir',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary),
                          ),
                          Text(
                            Rupiah.format(amount),
                            style: AppTextStyles.title.copyWith(
                              color: isIncome ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppCard(
                  color: isIncome
                      ? AppColors.success.withValues(alpha: 0.06)
                      : AppColors.danger.withValues(alpha: 0.06),
                  child: Column(
                    children: [
                      _detailRow('Nominal', Rupiah.format(amount), theme),
                      _detailRow('Kategori', categoryName, theme),
                      _detailRow('Dompet', walletName, theme),
                      if (desc.isNotEmpty) _detailRow('Keterangan', desc, theme),
                      _detailRow('Waktu Input', _formatTime(trx['created_at']?.toString()), theme),
                    ],
                  ),
                ),
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Bukti Foto Nota',
                    style: AppTextStyles.subheading.copyWith(
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (_, i) {
                        final photoUrl =
                            ApiService.resolvePhotoUrl(photos[i]['url']?.toString());
                        if (photoUrl == null || photoUrl.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Image.network(photoUrl, height: 100, width: 100, fit: BoxFit.cover),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Tutup'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.subheading.copyWith(
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
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
      appBar: AppBar(
        title: const Text('Aktivitas Hari Ini'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetchTransactions,
        child: Column(
          children: [
            Padding(
              padding: AppSpacing.pagePadding.copyWith(bottom: AppSpacing.xs),
              child: AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _summaryMetric(
                        label: 'Pemasukan',
                        value: Rupiah.format(_totalIncome),
                        color: AppColors.success,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: theme.dividerColor,
                    ),
                    Expanded(
                      child: _summaryMetric(
                        label: 'Pengeluaran',
                        value: Rupiah.format(_totalExpense),
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: AppSpacing.pagePadding.copyWith(top: AppSpacing.sm),
              child: Row(
                children: [
                  _filterChip('Semua', 'semua'),
                  const SizedBox(width: AppSpacing.sm),
                  _filterChip('Pemasukan', 'income'),
                  const SizedBox(width: AppSpacing.sm),
                  _filterChip('Pengeluaran', 'expense'),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTransactions.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.receipt_long_rounded,
                          title: 'Belum ada transaksi hari ini',
                          message: 'Ketuk tombol + di bawah untuk mencatat transaksi.',
                        )
                      : ListView.separated(
                          padding: AppSpacing.pagePadding.copyWith(top: 0),
                          itemCount: _filteredTransactions.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, index) {
                            final trx = _filteredTransactions[index];
                            return _buildTile(trx);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryMetric({required String label, required String value, required Color color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: AppTextStyles.heading.copyWith(color: color),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _selectedFilter == value;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border(context),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.label.copyWith(
            color: selected ? Colors.white : theme.textTheme.bodyLarge?.color,
          ),
        ),
      ),
    );
  }

  Widget _buildTile(Map<String, dynamic> trx) {
    final type = (trx['type'] ?? '').toString();
    final isIncome = type == 'income';
    final desc = htmlUnescape((trx['description'] ?? '').toString());
    final amount = _parseAmount(trx['amount']);

    final walletName = trx['wallet'] is Map ? trx['wallet']['name']?.toString() : null;
    final categoryName = trx['category'] is Map ? trx['category']['name']?.toString() : 'Umum';

    final displayTitle = desc.trim().isNotEmpty
        ? desc.trim()
        : '${isIncome ? 'Pemasukan' : 'Pengeluaran'} • $categoryName';

    final time = _formatTime(trx['created_at']?.toString());
    final subtitle = [if (time.isNotEmpty) time, if (walletName != null) walletName]
        .join(' • ');

    return TransactionTile(
      item: TransactionItem(
        title: displayTitle,
        subtitle: subtitle,
        amount: amount,
        isIncome: isIncome,
      ),
      onTap: () => _showDetailModal(trx),
    );
  }
}