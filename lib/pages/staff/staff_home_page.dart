import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../add_transaction_page.dart';

/// Beranda Staff CashMate:
/// Identitas Usaha, Quick Action Catat Transaksi, Statistik Input Hari Ini,
/// Daftar Dompet Usaha Aktif, dan Riwayat Singkat Transaksi Staff Hari Ini.
class StaffHomePage extends StatefulWidget {
  const StaffHomePage({super.key});

  @override
  State<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends State<StaffHomePage> {
  static const _blue = Color(0xFF0D6EFD);
  static const _amber = Color(0xFFFFB800);
  static const _green = Color(0xFF12B76A);
  static const _red = Color(0xFFE5484D);

  String staffName = '';
  String staffEmail = '';
  String businessName = '';
  String? staffPhotoUrl;

  // Ringkasan hari ini
  int todayCount = 0;
  double todayIncome = 0;
  double todayExpense = 0;

  List<Map<String, dynamic>> activeWallets = [];
  List<dynamic> todayTransactions = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => isLoading = true);
    await Future.wait([
      _loadIdentity(),
      _loadTodaySummary(),
      _loadActiveWallets(),
    ]);
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
        if (user['profile_photo'] != null && user['profile_photo'].toString().isNotEmpty) {
          staffPhotoUrl = ApiService.resolvePhotoUrl(user['profile_photo'].toString());
        }
      }
      final business = me['business'];
      if (business is Map) {
        businessName = (business['name'] ?? '').toString();
      }
    });
  }

  Future<void> _loadActiveWallets() async {
    final wallets = await ApiService.fetchWallets(status: 'active');
    if (!mounted) return;
    setState(() {
      activeWallets = wallets;
    });
  }

  Future<void> _loadTodaySummary() async {
    // Staff: API hanya mengembalikan transaksi sendiri hari ini
    final result = await ApiService.fetchTransactions(perPage: 50);
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
      todayTransactions = list;
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

  Future<void> _openAddTransactionPage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionPage()),
    );
    if (result == true && mounted) {
      _loadAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F1FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Image.asset(
                'assets/cashmate-logo.png',
                height: 24,
                width: 24,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.point_of_sale, color: _blue, size: 20),
              ),
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
                Text('Kasir & Operasional Staff', style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _loadAll,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ---- Greeting Banner ----
            _buildGreetingCard(theme),
            const SizedBox(height: 16),

            // ---- Quick Action Grid ----
            _buildQuickActions(theme),
            const SizedBox(height: 20),

            // ---- Summary Stat Card ----
            if (isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
            else ...[
              _buildSummaryCard(theme),
              const SizedBox(height: 20),

              // ---- Dompet Usaha Aktif ----
              _buildWalletsSection(theme),
              const SizedBox(height: 20),

              // ---- Transaksi Staff Hari Ini ----
              _buildTodayTransactionsSection(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingCard(ThemeData theme) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) {
      greeting = 'Selamat Pagi ☀️';
    } else if (hour < 17) {
      greeting = 'Selamat Siang 🌤️';
    } else {
      greeting = 'Selamat Malam 🌙';
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF002966), Color(0xFF0D6EFD), Color(0xFF1E6BFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _amber.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.white24,
            backgroundImage: (staffPhotoUrl != null && staffPhotoUrl!.isNotEmpty)
                ? NetworkImage(staffPhotoUrl!)
                : null,
            child: (staffPhotoUrl == null || staffPhotoUrl!.isEmpty)
                ? Text(
              staffName.isNotEmpty ? staffName[0].toUpperCase() : 'S',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            )
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  staffName.isNotEmpty ? staffName : 'Staff Kasir',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                if (businessName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.storefront_rounded, size: 13, color: _amber),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          businessName,
                          style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _amber.withValues(alpha: 0.6)),
            ),
            child: const Text('STAFF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Action Kasir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.hintColor)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _quickActionButton(
                label: 'Pemasukan',
                icon: Icons.add_circle_outline_rounded,
                color: _blue,
                onTap: _openAddTransactionPage,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _quickActionButton(
                label: 'Pengeluaran',
                icon: Icons.remove_circle_outline_rounded,
                color: _amber,
                onTap: _openAddTransactionPage,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quickActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Aktivitas Hari Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyLarge?.color)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$todayCount Transaksi', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _blue)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _statItem('Total Pemasukan', _formatRupiah(todayIncome), _green, Icons.arrow_downward, theme),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _statItem('Total Pengeluaran', _formatRupiah(todayExpense), _red, Icons.arrow_upward, theme),
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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

  Widget _buildWalletsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Dompet Usaha Aktif', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.hintColor)),
            Text('${activeWallets.length} Dompet', style: TextStyle(fontSize: 11, color: theme.hintColor)),
          ],
        ),
        const SizedBox(height: 10),
        if (activeWallets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),
            child: const Text('Belum ada dompet aktif dari Owner', style: TextStyle(fontSize: 12, color: Colors.grey)),
          )
        else
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: activeWallets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final w = activeWallets[index];
                return Container(
                  width: 150,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _blue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: _blue.withValues(alpha: 0.12),
                        child: const Icon(Icons.account_balance_wallet_outlined, color: _blue, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              w['name'] ?? 'Dompet',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              w['balance'] != null
                                  ? _formatRupiah((w['balance'] is num) ? (w['balance'] as num).toDouble() : double.tryParse(w['balance'].toString()) ?? 0)
                                  : (w['currency'] ?? 'IDR'),
                              style: const TextStyle(fontSize: 11, color: _blue, fontWeight: FontWeight.bold),
                            ),
                          ],
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

  Widget _buildTodayTransactionsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Catatan Input Hari Ini', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.hintColor)),
            if (todayTransactions.isNotEmpty)
              Text('${todayTransactions.length} Transaksi', style: TextStyle(fontSize: 11, color: _blue, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        if (todayTransactions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 40, color: theme.hintColor),
                  const SizedBox(height: 8),
                  Text('Belum ada transaksi hari ini', style: TextStyle(fontSize: 13, color: theme.hintColor, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('Tekan tombol "+ Catat Pemasukan" untuk mulai memasukkan data kasir', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: todayTransactions.length > 5 ? 5 : todayTransactions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final trx = todayTransactions[index];
              final isIncome = trx['type'] == 'income';
              final amount = (trx['amount'] is num) ? (trx['amount'] as num).toDouble() : double.tryParse(trx['amount'].toString()) ?? 0;
              final catName = trx['category'] is Map ? (trx['category']['name'] ?? 'Umum') : 'Umum';
              final walletName = trx['wallet'] is Map ? (trx['wallet']['name'] ?? 'Cash') : 'Cash';
              final desc = (trx['description'] ?? '').toString();

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
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
                          Text(
                            desc.isNotEmpty ? desc : catName,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textTheme.bodyLarge?.color),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(walletName, style: TextStyle(fontSize: 11, color: theme.hintColor)),
                              Text(' • $catName', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      (isIncome ? '+' : '-') + _formatRupiah(amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: isIncome ? _green : _red,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
