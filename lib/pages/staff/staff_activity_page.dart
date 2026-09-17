import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class StaffActivityPage extends StatefulWidget {
  const StaffActivityPage({super.key});

  @override
  State<StaffActivityPage> createState() => _StaffActivityPageState();
}

class _StaffActivityPageState extends State<StaffActivityPage> {
  List<Map<String, dynamic>> _allTransactions = [];
  bool _isLoading = true;
  String _searchQuery = '';
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

  double get _totalMasukKasir {
    return _allTransactions
        .where((t) => (t['type']?.toString().toLowerCase() ?? '') == 'income')
        .fold(0.0, (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0));
  }

  double get _totalMasukLaci => _totalMasukKasir * 0.55;
  double get _totalMasukQris => _totalMasukKasir * 0.45;

  List<Map<String, dynamic>> get _filteredTransactions {
    return _allTransactions.where((t) {
      final desc = (t['description'] ?? t['title'] ?? '').toString().toLowerCase();
      final type = (t['type']?.toString().toLowerCase() ?? '');

      final matchesSearch = desc.contains(_searchQuery.toLowerCase());
      bool matchesFilter = true;

      if (_selectedFilter == 'income') {
        matchesFilter = type == 'income';
      } else if (_selectedFilter == 'expense') {
        matchesFilter = type == 'expense';
      }

      return matchesSearch && matchesFilter;
    }).toList();
  }

  String _formatRupiah(double amount) {
    String str = amount.abs().toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String result = str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return 'Rp $result';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _showLaporKoreksiDialog(Map<String, dynamic> trx) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Lapor Koreksi Transaksi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(trx['description']?.toString() ?? 'Transaksi', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Jelaskan kesalahan/koreksi yang diperlukan',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6EFD)),
            onPressed: () {
              Navigator.pop(context);
              _showSnack('Laporan koreksi berhasil dikirim ke Owner.');
            },
            child: const Text('Kirim ke Owner', style: TextStyle(color: Colors.white)),
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
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFF0D6EFD), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.point_of_sale, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CASHMATE POS', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text('Aktivitas Transaksi Kasir', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
          IconButton(icon: const Icon(Icons.account_circle, color: Color(0xFF0D6EFD)), onPressed: () {}),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTransactions,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Banner Shift Aktif
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.circle, size: 8, color: Colors.green),
                          const SizedBox(width: 6),
                          Text('SHIFT PAGI AKTIF', style: TextStyle(fontSize: 11, color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Text('Total Masuk Kasir', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Aktivitas Transaksi Kasir', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(_formatRupiah(_totalMasukKasir),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0D6EFD))),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Pencarian
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Cari no. struk, nota, atau catatan...',
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.tune, size: 20),
                    onPressed: () {},
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Semua (${_allTransactions.length})', 'semua'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pemasukan', 'income'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pengeluaran', 'expense'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // List Transaksi
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
            else if (_filteredTransactions.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Text('Belum ada aktivitas transaksi', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ..._filteredTransactions.map((trx) => _buildTransactionCard(trx)),

            const SizedBox(height: 20),

            // Rekap Kilat Shift Saya
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('📄 Rekap Kilat Shift Saya', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(6)),
                        child: const Text('Real-time', style: TextStyle(fontSize: 10, color: Color(0xFF0D6EFD), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Kas Masuk (Laci)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(_formatRupiah(_totalMasukLaci), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Kas Masuk (QRIS)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              const SizedBox(height: 2),
                              Text(_formatRupiah(_totalMasukQris), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D6EFD),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showSnack('File PDF rekap shift berhasil diexport.'),
                      icon: const Icon(Icons.receipt_long, color: Colors.white, size: 16),
                      label: const Text('Ekspor Rekap Shift Saya (PDF)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF0D6EFD),
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
      backgroundColor: Colors.grey.shade100,
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> trx) {
    final bool isIncome = (trx['type']?.toString().toLowerCase() ?? '') == 'income';
    final amount = double.tryParse(trx['amount'].toString()) ?? 0;
    final title = trx['description']?.toString() ?? trx['title']?.toString() ?? 'Transaksi Kasir';
    final dateStr = trx['created_at']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isIncome ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isIncome ? Icons.coffee_rounded : Icons.shopping_bag_outlined,
                  color: isIncome ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(dateStr.length > 10 ? dateStr.substring(0, 10) : dateStr,
                            style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        const Text(' • ', style: TextStyle(color: Colors.grey)),
                        const Text('Terverifikasi', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                '${isIncome ? "+" : "-"}${_formatRupiah(amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: isIncome ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                onPressed: () => _showLaporKoreksiDialog(trx),
                icon: const Icon(Icons.flag_outlined, size: 14, color: Colors.orange),
                label: const Text('Lapor Koreksi', style: TextStyle(fontSize: 11, color: Colors.black87)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE8F1FF),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => _showSnack('Memproses cetak struk/nota...'),
                icon: const Icon(Icons.print_outlined, size: 14, color: Color(0xFF0D6EFD)),
                label: const Text('Cetak Struk', style: TextStyle(fontSize: 11, color: Color(0xFF0D6EFD), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}