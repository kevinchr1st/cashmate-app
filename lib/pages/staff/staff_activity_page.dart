import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Daftar transaksi Staff hari ini dengan filter pemasukan/pengeluaran & modal detail transaksi.
/// Staff API hanya mengembalikan transaksi milik sendiri hari ini.
class StaffActivityPage extends StatefulWidget {
  const StaffActivityPage({super.key});

  @override
  State<StaffActivityPage> createState() => _StaffActivityPageState();
}

class _StaffActivityPageState extends State<StaffActivityPage> {
  static const _blue = Color(0xFF0D6EFD);
  static const _amber = Color(0xFFFFB800);
  static const _green = Color(0xFF12B76A);
  static const _red = Color(0xFFE5484D);

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

  void _showDetailModal(Map<String, dynamic> trx) {
    final type = (trx['type'] ?? '').toString();
    final isIncome = type == 'income';
    final desc = (trx['description'] ?? '').toString();
    final amount = _parseAmount(trx['amount']);

    final walletName = trx['wallet'] is Map ? (trx['wallet']['name']?.toString() ?? 'Cash') : 'Cash';
    final categoryName = trx['category'] is Map ? (trx['category']['name']?.toString() ?? 'Umum') : 'Umum';
    final photos = trx['photos'] as List<dynamic>? ?? [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogCtx) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.hintColor.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: (isIncome ? _blue : _amber).withValues(alpha: 0.15),
                      child: Icon(
                        isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: isIncome ? _blue : _amber,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isIncome ? 'Pemasukan Kasir' : 'Pengeluaran Kasir',
                            style: TextStyle(fontSize: 12, color: theme.hintColor, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _formatRupiah(amount),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isIncome ? _green : _red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                _detailRow('Nominal', _formatRupiah(amount), theme),
                _detailRow('Kategori', categoryName, theme),
                _detailRow('Dompet', walletName, theme),
                if (desc.isNotEmpty) _detailRow('Keterangan', desc, theme),
                _detailRow('Waktu Input', _formatTime(trx['created_at']?.toString()), theme),
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text('Bukti Foto Nota', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.hintColor)),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final photoUrl = ApiService.resolvePhotoUrl(photos[i]['url']?.toString());
                        if (photoUrl == null || photoUrl.isEmpty) return const SizedBox.shrink();
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(photoUrl, height: 100, width: 100, fit: BoxFit.cover),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Tutup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: theme.hintColor)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
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
                  Expanded(child: _summaryChip('Pemasukan', _formatRupiah(_totalIncome), _blue, theme)),
                  const SizedBox(width: 8),
                  Expanded(child: _summaryChip('Pengeluaran', _formatRupiah(_totalExpense), _amber, theme)),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: theme.hintColor)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
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
          border: Border.all(color: selected ? _blue : theme.dividerColor.withValues(alpha: 0.2)),
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

    final walletName = trx['wallet'] is Map ? trx['wallet']['name']?.toString() : null;
    final categoryName = trx['category'] is Map ? trx['category']['name']?.toString() : null;

    final displayTitle = desc.trim().isNotEmpty
        ? desc.trim()
        : categoryName != null
        ? '${isIncome ? 'Pemasukan' : 'Pengeluaran'} • $categoryName'
        : 'Transaksi';

    return InkWell(
      onTap: () => _showDetailModal(trx),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: (isIncome ? _blue : _amber).withValues(alpha: 0.12),
              child: Icon(
                isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                color: isIncome ? _blue : _amber,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textTheme.bodyLarge?.color)),
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
                color: (isIncome ? _green : _red).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${isIncome ? "+" : "-"} ${_formatRupiah(amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: isIncome ? _green : _red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 48, color: theme.hintColor),
              const SizedBox(height: 12),
              Text('Belum ada transaksi hari ini', style: TextStyle(color: theme.hintColor, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Ketuk tombol + di bawah untuk mencatat transaksi.', style: TextStyle(fontSize: 11, color: theme.hintColor)),
              const SizedBox(height: 12),
              Text('Tarik ke bawah (pull to refresh) untuk memperbarui data', style: TextStyle(fontSize: 10, color: theme.hintColor.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ],
    );
  }
}