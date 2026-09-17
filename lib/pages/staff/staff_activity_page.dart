import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Daftar transaksi Staff hari ini dengan filter pemasukan/pengeluaran.
/// Staff API hanya mengembalikan transaksi milik sendiri hari ini.
class StaffActivityPage extends StatefulWidget {
  const StaffActivityPage({super.key});

  @override
  State<StaffActivityPage> createState() => _StaffActivityPageState();
}

class _StaffActivityPageState extends State<StaffActivityPage> {
  static const _blue = Color(0xFF0D6EFD);

  List<Map<String, dynamic>> _allTransactions = [];
  bool _isLoading = true;
  String _selectedFilter = 'semua'; // 'semua', 'income', 'expense'

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
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

  double _parseAmount(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  String _formatRupiah(double amount) {
    String str = amount.abs().toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String result = str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return 'Rp $result';
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
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
              child: const Icon(Icons.list_alt_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Text('Aktivitas Hari Ini', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTransactions,
        child: Column(
          children: [
            // Summary row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(child: _summaryChip('Pemasukan', _formatRupiah(_totalIncome), Colors.green, theme)),
                  const SizedBox(width: 8),
                  Expanded(child: _summaryChip('Pengeluaran', _formatRupiah(_totalExpense), Colors.red, theme)),
                ],
              ),
            ),
            // Filter chips
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  _filterChip('Semua', 'semua', theme),
                  const SizedBox(width: 8),
                  _filterChip('Pemasukan', 'income', theme),
                  const SizedBox(width: 8),
                  _filterChip('Pengeluaran', 'expense', theme),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredTransactions.isEmpty
                  ? _emptyState(theme)
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: _filteredTransactions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _buildTile(_filteredTransactions[index], theme);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(String label, String value, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: theme.hintColor)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, ThemeData theme) {
    final selected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _blue : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _blue : theme.dividerColor.withOpacity(0.2)),
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

  Widget _buildTile(Map<String, dynamic> trx, ThemeData theme) {
    final type = (trx['type'] ?? '').toString();
    final isIncome = type == 'income';
    final desc = (trx['description'] ?? '').toString();
    final amount = _parseAmount(trx['amount']);

    // Nested wallet/category dari API response
    final walletName = trx['wallet'] is Map ? trx['wallet']['name']?.toString() : null;
    final categoryName = trx['category'] is Map ? trx['category']['name']?.toString() : null;

    final displayTitle = desc.trim().isNotEmpty
        ? desc.trim()
        : categoryName != null
        ? '${isIncome ? 'Pemasukan' : 'Pengeluaran'} • $categoryName'
        : 'Transaksi';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: isIncome ? Colors.green.shade50 : Colors.red.shade50,
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? Colors.green : Colors.red,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: theme.textTheme.bodyLarge?.color)),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 6,
                  children: [
                    Text(_formatTime(trx['created_at']?.toString()), style: TextStyle(fontSize: 11, color: theme.hintColor)),
                    if (walletName != null)
                      Text('• $walletName', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isIncome ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${isIncome ? "+" : "-"} ${_formatRupiah(amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 48, color: theme.hintColor),
          const SizedBox(height: 12),
          Text('Belum ada transaksi hari ini', style: TextStyle(color: theme.hintColor, fontSize: 13)),
          const SizedBox(height: 6),
          Text('Ketuk tombol + untuk mencatat transaksi.', style: TextStyle(fontSize: 11, color: theme.hintColor)),
        ],
      ),
    );
  }
}