import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/string_utils.dart';

class KasirPage extends StatefulWidget {
  const KasirPage({super.key});

  @override
  State<KasirPage> createState() => _KasirPageState();
}

class _KasirPageState extends State<KasirPage> {
  String staffName = 'Rina';
  String? businessName = 'Toko Makmur Jaya • POS-01';

  List<Map<String, dynamic>> wallets = [];
  List<Map<String, dynamic>> categories = [];
  bool isLoadingMaster = true;

  String selectedType = 'income'; // 'income' atau 'expense'
  Map<String, dynamic>? selectedWallet;
  Map<String, dynamic>? selectedCategory;
  final amountController = TextEditingController(text: '0');
  final noteController = TextEditingController();
  bool isSaving = false;

  List<Map<String, dynamic>> todayTransactions = [];
  bool isLoadingActivities = true;

  List<Map<String, dynamic>> get _filteredCategories =>
      categories.where((c) => c['type'] == selectedType).toList();

  double get _amount => double.tryParse(amountController.text.replaceAll('.', '')) ?? 0;

  double get _totalMasukHariIni => todayTransactions
      .where((t) => t['type'] == 'income')
      .fold(0.0, (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0));

  double get _totalKeluarHariIni => todayTransactions
      .where((t) => t['type'] == 'expense')
      .fold(0.0, (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0));

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadMasterData();
    _loadTodayActivities();
  }

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final me = await ApiService.getCurrentUser();
    if (!mounted || me == null) return;
    setState(() {
      if (me['name'] != null) staffName = me['name'].toString();
      final business = me['business'];
      if (business is Map && business['name'] != null) {
        businessName = business['name'].toString();
      }
    });
  }

  Future<void> _loadMasterData() async {
    setState(() => isLoadingMaster = true);
    final fetchedWallets = await ApiService.fetchWallets();
    final fetchedCategories = await ApiService.fetchCategories();
    if (!mounted) return;
    setState(() {
      wallets = fetchedWallets;
      categories = fetchedCategories;
      if (wallets.isNotEmpty) selectedWallet = wallets.first;
      if (_filteredCategories.isNotEmpty) selectedCategory = _filteredCategories.first;
      isLoadingMaster = false;
    });
  }

  Future<void> _loadTodayActivities() async {
    setState(() => isLoadingActivities = true);
    // Menggunakan fetchTransactions sesuai parameter ApiService yang valid
    final result = await ApiService.fetchTransactions(
      perPage: 50,
    );
    if (!mounted) return;
    setState(() {
      final list = result['data'] as List<dynamic>? ?? [];
      todayTransactions = list.map((e) => Map<String, dynamic>.from(e)).toList();
      isLoadingActivities = false;
    });
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadMasterData(), _loadTodayActivities()]);
  }

  void _addQuickAmount(double add) {
    setState(() {
      amountController.text = (_amount + add).toStringAsFixed(0);
    });
  }

  void _setExactAmount(double value) {
    setState(() {
      amountController.text = value.toStringAsFixed(0);
    });
  }

  Future<void> _saveTransaction() async {
    if (_amount <= 0) {
      _showSnack('Nominal transaksi wajib diisi!', isError: true);
      return;
    }
    if (selectedWallet == null || selectedCategory == null) {
      _showSnack('Pilih sumber dana dan kategori terlebih dahulu!', isError: true);
      return;
    }

    setState(() => isSaving = true);

    final result = await ApiService.createTransaction(
      walletId: int.parse(selectedWallet!['id'].toString()),
      categoryId: int.parse(selectedCategory!['id'].toString()),
      amount: _amount,
      type: selectedType,
      description: noteController.text.trim().isEmpty
          ? (selectedType == 'income' ? 'Penjualan Kasir' : 'Pengeluaran Kasir')
          : noteController.text.trim(),
    );

    if (!mounted) return;
    setState(() => isSaving = false);

    if (result['success'] == true) {
      amountController.text = '0';
      noteController.clear();
      _showSnack('Transaksi kasir berhasil disimpan!');
      _loadTodayActivities();
    } else {
      _showSnack(result['message'] ?? 'Gagal menyimpan transaksi', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: isError ? Colors.red : Colors.green),
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
            Text(htmlUnescape(trx['description']?.toString() ?? 'Transaksi'), style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _showTutupShiftDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hitung Fisik & Tutup Shift $staffName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Text(
          'Ringkasan shift hari ini:\n\n'
              'Total Transaksi: ${todayTransactions.length}\n'
              'Kas Masuk: ${_formatRupiah(_totalMasukHariIni)}\n'
              'Kas Keluar: ${_formatRupiah(_totalKeluarHariIni)}\n\n'
              'Pastikan uang fisik di laci cocok dengan rekap.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D6EFD)),
            onPressed: () {
              Navigator.pop(context);
              _showSnack('Shift berhasil ditutup.');
            },
            child: const Text('Konfirmasi Tutup Shift', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatRupiah(double amount) {
    String str = amount.toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String result = str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return 'Rp $result';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                Text('Layar Kasir Operasional', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.bolt, size: 16, color: Colors.amber),
            label: const Text('Cepat', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header Staff Info
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(staffName.isNotEmpty ? staffName[0].toUpperCase() : 'R',
                      style: const TextStyle(color: Color(0xFF0D6EFD), fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('$staffName (Staff Kasir)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: const Color(0xFFE8F1FF), borderRadius: BorderRadius.circular(6)),
                            child: const Text('Shift Pagi', style: TextStyle(fontSize: 9, color: Color(0xFF0D6EFD), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      if (businessName != null)
                        Text(businessName!, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.lock_outline, size: 12, color: Colors.green),
                      SizedBox(width: 4),
                      Text('Saldo Toko Terlindungi', style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Rekap Shift Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D6EFD), Color(0xFF1E6BFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('REKAP SHIFT SAYA HARI INI', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(6)),
                        child: const Text('08:00 - 16:00', style: TextStyle(color: Colors.white, fontSize: 10)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('${todayTransactions.length} Transaksi (Server Pikes Sistem)',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildShiftStat('Kas Masuk Shift', _totalMasukHariIni, Colors.greenAccent)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildShiftStat('Petty Cash Keluar', _totalKeluarHariIni, Colors.orangeAccent)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('🔒 Arsip Shift: Saldo Toko Terkunci di Owner | Info SOP',
                      style: TextStyle(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text('PILIH JENIS TRANSAKSI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _buildTypeCard('income', '+ Tambah Pemasukan', 'Penjualan / Kas Masuk', Icons.add_circle_outline, Colors.blue)),
                const SizedBox(width: 10),
                Expanded(child: _buildTypeCard('expense', '- Tambah Pengeluaran', 'Petty Cash Kasir', Icons.remove_circle_outline, Colors.orange)),
              ],
            ),

            const SizedBox(height: 20),

            // Form Input
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(selectedType == 'income' ? 'FORM INPUT PEMASUKAN KASIR' : 'FORM INPUT PENGELUARAN KASIR',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const Text('⚡ Mode Cepat', style: TextStyle(fontSize: 11, color: Color(0xFF0D6EFD), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Nominal Transaksi (Rp) *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D6EFD)),
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      prefixStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0D6EFD)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildQuickChip('+10rb', () => _addQuickAmount(10000)),
                      _buildQuickChip('+20rb', () => _addQuickAmount(20000)),
                      _buildQuickChip('+50rb', () => _addQuickAmount(50000)),
                      _buildQuickChip('+100rb', () => _addQuickAmount(100000)),
                      _buildQuickChip('Pas 50rb', () => _setExactAmount(50000), highlighted: true),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Text('Disimpan Ke / Sumber Dana *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: wallets.map((w) {
                      final selected = selectedWallet != null && selectedWallet!['id'] == w['id'];
                      return _buildSelectableCard(
                        label: w['name']?.toString() ?? 'Wallet',
                        icon: Icons.account_balance_wallet,
                        selected: selected,
                        onTap: () => setState(() => selectedWallet = w),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  const Text('Kategori (Disediakan Owner) *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _filteredCategories.map((c) {
                      final selected = selectedCategory != null && selectedCategory!['id'] == c['id'];
                      return _buildSelectableCard(
                        label: c['name']?.toString() ?? 'Kategori',
                        icon: Icons.sell_outlined,
                        selected: selected,
                        onTap: () => setState(() => selectedCategory = c),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),
                  const Text('Catatan transaksi (Opsional)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      hintText: 'Cth: Meja 04, Pesanan Kopi Susu 2x',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D6EFD),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving ? null : _saveTransaction,
                      icon: const Icon(Icons.save_outlined, color: Colors.white, size: 18),
                      label: const Text('Simpan Transaksi Kasir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Aktivitas Kasir Hari Ini', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text('${todayTransactions.length} Baru', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: const Text(
                'Ketentuan Keamanan: Transaksi tersimpan tidak dapat diubah/dihapus oleh Staff. '
                    'Jika terjadi salah input, segera tekan tombol "Lapor Koreksi" untuk diverifikasi Owner.',
                style: TextStyle(fontSize: 11, color: Colors.brown),
              ),
            ),

            if (isLoadingActivities)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (todayTransactions.isEmpty)
              const Center(child: Text('Belum ada transaksi hari ini', style: TextStyle(color: Colors.grey)))
            else
              ...todayTransactions.map((trx) => _buildActivityTile(trx)),

            const SizedBox(height: 20),

            // Tutup Shift Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Akan mengakhiri jam kerja shift?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Pastikan uang fisik di laci kasir cocok dengan rekap input sebelum serah terima kasir.',
                      style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _showTutupShiftDialog,
                      child: Text('Hitung Fisik & Tutup Shift $staffName'),
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

  Widget _buildShiftStat(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(height: 2),
          Text(_formatRupiah(value),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildTypeCard(String type, String title, String subtitle, IconData icon, Color color) {
    final bool selected = selectedType == type;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() {
        selectedType = type;
        selectedCategory = _filteredCategories.isNotEmpty ? _filteredCategories.first : null;
      }),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            if (selected)
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  child: const Text('AKTIF', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 6),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap, {bool highlighted = false}) {
    return ActionChip(
      label: Text(label, style: TextStyle(fontSize: 11, color: highlighted ? Colors.white : null, fontWeight: FontWeight.bold)),
      backgroundColor: highlighted ? const Color(0xFF0D6EFD) : null,
      onPressed: onTap,
    );
  }

  Widget _buildSelectableCard({required String label, required IconData icon, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFE8F1FF) : Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? const Color(0xFF0D6EFD) : Colors.grey.shade300, width: selected ? 2 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? const Color(0xFF0D6EFD) : Colors.grey.shade700),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: selected ? const Color(0xFF0D6EFD) : Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(Map<String, dynamic> trx) {
    final bool isIncome = trx['type'] == 'income';
    final amount = double.tryParse(trx['amount'].toString()) ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
                child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: isIncome ? Colors.green : Colors.red, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(htmlUnescape(trx['description']?.toString() ?? 'Transaksi'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(trx['created_at']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              Text('${isIncome ? "+" : "-"} ${_formatRupiah(amount)}',
                  style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.lock_outline, size: 12, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('Terkunci / Staff Role', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _showLaporKoreksiDialog(trx),
                child: const Text('⚠️ Lapor Koreksi', style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}