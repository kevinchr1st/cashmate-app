import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Beranda Staff: identitas usaha dan ringkasan aktivitas hari ini.
/// Data dari /auth/me (user + business). Tidak menampilkan saldo/dashboard Owner.
class StaffHomePage extends StatefulWidget {
  const StaffHomePage({super.key});

  @override
  State<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends State<StaffHomePage> {
  static const _blue = Color(0xFF0D6EFD);
  static const _green = Color(0xFF12B76A);
  static const _red = Color(0xFFE5484D);

  String staffName = '';
  String staffEmail = '';
  String businessName = '';

  // Ringkasan hari ini
  int todayCount = 0;
  double todayIncome = 0;
  double todayExpense = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => isLoading = true);
    await Future.wait([_loadIdentity(), _loadTodaySummary()]);
    if (mounted) setState(() => isLoading = false);
  }

  Future<void> _loadIdentity() async {
    final me = await ApiService.getCurrentUser();
    if (!mounted || me == null) return;
    setState(() {
      final user = me['user'];
      if (user is Map) {
        staffName = (user['name'] ?? '').toString();
        staffEmail = (user['email'] ?? '').toString();
      }
      final business = me['business'];
      if (business is Map) {
        businessName = (business['name'] ?? '').toString();
      }
    });
  }

  Future<void> _loadTodaySummary() async {
    // Staff: API hanya mengembalikan transaksi sendiri hari ini
    final result = await ApiService.fetchTransactions(perPage: 100);
    if (!mounted) return;

    final list = result['data'] as List<dynamic>? ?? [];
    double inc = 0, exp = 0;
    for (final trx in list) {
      final amount = (trx['amount'] is num) ? (trx['amount'] as num).toDouble() : double.tryParse(trx['amount'].toString()) ?? 0;
      final type = (trx['type'] ?? '').toString();
      if (type == 'income') {
        inc += amount;
      } else {
        exp += amount;
      }
    }

    setState(() {
      todayCount = list.length;
      todayIncome = inc;
      todayExpense = exp;
    });
  }

  String _formatRupiah(double amount) {
    String str = amount.toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String result = str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return 'Rp $result';
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
              child: const Icon(Icons.point_of_sale, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CASHMATE', style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.bold)),
                Text('Beranda Staff', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
              ],
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          children: [
            // Greeting card
            _buildGreetingCard(theme),
            const SizedBox(height: 20),

            // Summary card
            if (isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else
              _buildSummaryCard(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingCard(ThemeData theme) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Selamat Pagi';
    } else if (hour < 17) {
      greeting = 'Selamat Siang';
    } else {
      greeting = 'Selamat Malam';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_blue, Color(0xFF2E7BF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: _blue.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting, style: const TextStyle(fontSize: 12, color: Colors.white70)),
          const SizedBox(height: 4),
          Text(
            staffName.isNotEmpty ? staffName : 'Staff',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          if (businessName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.storefront, size: 14, color: Colors.white70),
                const SizedBox(width: 4),
                Text(businessName, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('STAFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ringkasan Hari Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 4),
          Text('$todayCount transaksi dicatat', style: TextStyle(fontSize: 12, color: theme.hintColor)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statItem('Pemasukan', _formatRupiah(todayIncome), _green, Icons.arrow_downward, theme),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statItem('Pengeluaran', _formatRupiah(todayExpense), _red, Icons.arrow_upward, theme),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color, IconData icon, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: theme.hintColor)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
