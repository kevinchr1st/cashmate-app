import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class StaffHistoryPage extends StatefulWidget {
  const StaffHistoryPage({super.key});

  @override
  State<StaffHistoryPage> createState() => _StaffHistoryPageState();
}

class _StaffHistoryPageState extends State<StaffHistoryPage> {
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    final result = await ApiService.fetchTransactions(perPage: 100);
    if (!mounted) return;
    setState(() {
      _transactions = (result['data'] as List<Map<String, dynamic>>?) ?? [];
      _isLoading = false;
    });
  }

  double get _kasMasuk {
    return _transactions
        .where((t) => (t['type']?.toString().toLowerCase() ?? '') == 'income')
        .fold(0.0, (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0));
  }

  double get _kasKeluar {
    return _transactions
        .where((t) => (t['type']?.toString().toLowerCase() ?? '') == 'expense')
        .fold(0.0, (sum, t) => sum + (double.tryParse(t['amount'].toString()) ?? 0));
  }

  final double _kasAwal = 300000; // Modal awal shift

  double get _targetFisik => _kasAwal + _kasMasuk - _kasKeluar;

  String _formatRupiah(double amount) {
    String str = amount.abs().toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String result = str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return '${amount < 0 ? '-' : ''}Rp $result';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
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
                Text('Shift Pagi - POS-01', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
        onRefresh: _fetchHistory,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header Shift Aktif & Durasi
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.access_time, color: Color(0xFF0D6EFD), size: 20),
                          ),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Shift Pagi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.circle, size: 8, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text('Aktif Sekarang', style: TextStyle(fontSize: 11, color: Colors.green, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20)),
                        child: const Text('⏱️ 6j 15m', style: TextStyle(fontSize: 11, color: Color(0xFF0D6EFD), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Serah terima badge
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('Serah Terima Diterima Pagi', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Icon(Icons.check_circle, color: Colors.green, size: 18),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4 Kotak Statistik (Kas Awal, Kas Masuk, Kas Keluar, Target Fisik)
                  Row(
                    children: [
                      Expanded(child: _buildStatBox('Kas Awal', _formatRupiah(_kasAwal), Colors.blue.shade700, Icons.account_balance_wallet_outlined)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildStatBox('Kas Masuk', '+${_formatRupiah(_kasMasuk)}', Colors.green, Icons.arrow_downward)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildStatBox('Kas Keluar', '-${_formatRupiah(_kasKeluar)}', Colors.red, Icons.arrow_upward)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildStatBox('Target Fisik', _formatRupiah(_targetFisik), const Color(0xFF0D6EFD), Icons.point_of_sale)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Target Fisik Besar
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatRupiah(_targetFisik),
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0D6EFD))),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.check_circle, size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            Text('Termasuk ${_transactions.length} transaksi tercatat',
                                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tombol Hitung Kas & Tutup Shift
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D6EFD),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => _showSnack('Membuka wizard hitung kas & tutup shift...'),
                      icon: const Icon(Icons.lock_outline, color: Colors.white, size: 18),
                      label: const Text('Hitung Kas & Tutup Shift',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Panduan SOP
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.assignment_outlined, size: 20, color: Colors.amber),
                      SizedBox(width: 10),
                      Text('Panduan SOP Serah Terima', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  TextButton(
                    onPressed: () => _showSnack('Membuka petunjuk SOP...'),
                    child: const Text('Buka Petunjuk', style: TextStyle(fontSize: 12, color: Color(0xFF0D6EFD), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Cetak Slip Sementara
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.receipt_outlined, size: 20, color: Colors.brown),
                      SizedBox(width: 10),
                      Text('Cetak Slip Sementara', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8F1FF),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _showSnack('Mencetak slip sementara shift...'),
                    child: const Text('Cetak', style: TextStyle(fontSize: 12, color: Color(0xFF0D6EFD), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Bagian Riwayat Shift Kasir
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Riwayat Shift Kasir', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                Text('3 Shift Terakhir', style: TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),

            // Kartu Riwayat 1
            _buildHistoryShiftCard(
              title: 'Shift Pagi • 08 Sep 2026',
              status: 'Tuntas • Balance',
              statusColor: Colors.green,
              subtitle: '📄 24 Struk Penjualan',
              fisik: 'Kas Fisik: Rp 1.180.000',
            ),
            const SizedBox(height: 10),

            // Kartu Riwayat 2
            _buildHistoryShiftCard(
              title: 'Shift Sore • 07 Sep 2026',
              status: 'Lebih (+Rp 2.000)',
              statusColor: Colors.amber.shade800,
              subtitle: 'Catatan: Selisih tip kembalian pembulatan tunai +Rp 2.000',
              fisik: '',
              isWarning: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildHistoryShiftCard({
    required String title,
    required String status,
    required Color statusColor,
    required String subtitle,
    required String fisik,
    bool isWarning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isWarning ? Colors.amber.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status, style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          if (fisik.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(fisik, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black87)),
          ],
        ],
      ),
    );
  }
}