import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart'; // Naik dua level ke folder services/
import 'transaction_page.dart'; // Berada di folder owner yang sama

/// Dipakai halaman lain (mis. setelah transaksi baru disimpan dari bottom nav)
/// untuk memaksa Beranda memuat ulang datanya tanpa harus pindah tab.
final ValueNotifier<int> dashboardRefreshNotifier = ValueNotifier<int>(0);

/// Dipakai Beranda untuk meminta bottom navigation berpindah ke tab
/// "Kantong Kas" — lebih baik daripada push halaman baru, karena Kantong
/// sekarang adalah tab tengah dan tidak punya tombol kembali.
final ValueNotifier<int> openKantongTabNotifier = ValueNotifier<int>(0);

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // ---- Palet warna (disamakan dengan mockup CashMate) ----
  static const Color _blue = Color(0xFF1155D9);
  static const Color _blueSoft = Color(0xFFE8F0FE);
  static const Color _green = Color(0xFF12B76A);
  static const Color _red = Color(0xFFE5484D);
  static const Color _amber = Color(0xFFF5A524);
  static const Color _indigoSoft = Color(0xFFEEF2FF);

  bool _isLoading = true;
  bool _balanceVisible = true;
  bool _isOwner = true;

  String _ownerName = '';
  String _storeName = '';

  double _totalBalance = 0;
  double _monthIncome = 0;
  double _monthExpense = 0;
  double _netCashflow = 0;
  int _incomeCount = 0;
  int _expenseCount = 0;

  List<Map<String, dynamic>> _wallets = [];
  List<Map<String, dynamic>> _transactions = [];
  List<Map<String, dynamic>> _monthlyReport = [];
  final Map<int, Map<String, dynamic>> _categoryById = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
    dashboardRefreshNotifier.addListener(_loadAll);
  }

  @override
  void dispose() {
    dashboardRefreshNotifier.removeListener(_loadAll);
    super.dispose();
  }

  // ---------------------------------------------------------------- data ----

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    _isOwner = await ApiService.isOwner();
    await _loadIdentity();

    // Semua endpoint di bawah persis seperti di Postman collection:
    //   GET /wallets?status=active
    //   GET /categories?status=active
    //   GET /transactions?page=1&per_page=…
    //   GET /dashboard/summary          (Owner saja, Staff dapat 403)
    //   GET /reports/monthly?year=…     (Owner saja)
    final results = await Future.wait<dynamic>([
      ApiService.fetchWallets(status: 'active'),
      ApiService.fetchCategories(status: 'active'),
      ApiService.fetchTransactions(perPage: 50),
      if (_isOwner) ApiService.getDashboardSummary(),
      if (_isOwner) ApiService.getMonthlyReport(year: DateTime.now().year),
    ]);

    if (!mounted) return;

    _wallets = List<Map<String, dynamic>>.from(results[0] as List);

    _categoryById.clear();
    for (final c in List<Map<String, dynamic>>.from(results[1] as List)) {
      final id = int.tryParse(c['id']?.toString() ?? '');
      if (id != null) _categoryById[id] = c;
    }

    final trxResult = results[2] as Map<String, dynamic>;
    _transactions = List<Map<String, dynamic>>.from(trxResult['data'] ?? []);

    if (_isOwner) {
      final summary = results[3] as Map<String, dynamic>?;
      if (summary != null) {
        _totalBalance = _toDouble(summary['total_balance']);
        _monthIncome = _toDouble(summary['current_month_income']);
        _monthExpense = _toDouble(summary['current_month_expense']);
        _netCashflow = _toDouble(summary['net_cashflow']);
      } else {
        _computeSummaryLocally();
      }
      _monthlyReport = List<Map<String, dynamic>>.from(results[4] as List);
    } else {
      // Staff tidak boleh memanggil /dashboard/summary (403) dan saldo wallet
      // memang disembunyikan backend, jadi angkanya dihitung dari transaksi
      // yang boleh dia lihat sendiri.
      _computeSummaryLocally();
      _monthlyReport = [];
    }

    _countThisMonthTransactions();
    setState(() => _isLoading = false);
  }

  Future<void> _loadIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('saved_owner_name');
    final savedStore = prefs.getString('saved_store_name');
    if (savedName != null && savedName.isNotEmpty) _ownerName = savedName;
    if (savedStore != null && savedStore.isNotEmpty) _storeName = savedStore;

    final me = await ApiService.getCurrentUser();
    if (me == null) return;
    final user = me['user'];
    final business = me['business'];
    if (user is Map && user['name'] != null) {
      _ownerName = user['name'].toString();
    }
    if (business is Map && business['name'] != null) {
      _storeName = business['name'].toString();
    }
  }

  void _computeSummaryLocally() {
    final now = DateTime.now();
    double income = 0;
    double expense = 0;
    for (final t in _transactions) {
      final date = _dateOf(t);
      if (date == null || date.year != now.year || date.month != now.month) {
        continue;
      }
      if (_isIncome(t)) {
        income += _toDouble(t['amount']);
      } else {
        expense += _toDouble(t['amount']);
      }
    }
    _monthIncome = income;
    _monthExpense = expense;
    _netCashflow = income - expense;
    if (_isOwner) {
      _totalBalance = _wallets.fold<double>(
        0,
            (sum, w) => sum + _toDouble(w['balance']),
      );
    }
  }

  void _countThisMonthTransactions() {
    final now = DateTime.now();
    int inCount = 0;
    int outCount = 0;
    for (final t in _transactions) {
      final date = _dateOf(t);
      if (date == null || date.year != now.year || date.month != now.month) {
        continue;
      }
      if (_isIncome(t)) {
        inCount++;
      } else {
        outCount++;
      }
    }
    _incomeCount = inCount;
    _expenseCount = outCount;
  }

  // ------------------------------------------------------------- helpers ----

  static double _toDouble(dynamic v) =>
      v == null ? 0 : (num.tryParse(v.toString())?.toDouble() ?? 0);

  static bool _isIncome(Map<String, dynamic> t) =>
      (t['type']?.toString().toLowerCase() ?? '') == 'income';

  static DateTime? _dateOf(Map<String, dynamic> t) {
    final raw = t['date'] ?? t['transaction_date'] ?? t['created_at'];
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  String _categoryNameOf(Map<String, dynamic> t) {
    final embedded = t['category'];
    if (embedded is Map && embedded['name'] != null) {
      return embedded['name'].toString();
    }
    final id = int.tryParse(t['category_id']?.toString() ?? '');
    final cat = id == null ? null : _categoryById[id];
    return cat?['name']?.toString() ?? 'Tanpa Kategori';
  }

  String _rp(double amount) {
    final negative = amount < 0;
    final str = amount.abs().toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formatted = str.replaceAllMapped(reg, (m) => '${m[1]}.');
    return '${negative ? '-' : ''}Rp $formatted';
  }

  String _rpShort(double amount) {
    if (amount.abs() >= 1000000000) {
      return 'Rp ${(amount / 1000000000).toStringAsFixed(1).replaceAll('.', ',')} M';
    }
    if (amount.abs() >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1).replaceAll('.', ',')} Jt';
    }
    if (amount.abs() >= 1000) {
      return 'Rp ${(amount / 1000).toStringAsFixed(0)} rb';
    }
    return _rp(amount);
  }

  String get _firstName {
    if (_ownerName.trim().isEmpty) return 'Sobat CashMate';
    return _ownerName.trim().split(' ').first;
  }

  // ------------------------------------------------------------ navigasi ----

  Future<void> _openTransactionPage() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id') ?? 1;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TransactionPage(userId: userId)),
    );
    _loadAll();
  }

  void _openWalletPage() {
    openKantongTabNotifier.value++;
  }

  // --------------------------------------------------------------- build ----

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _blue,
          onRefresh: _loadAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            children: [
              _header(),
              const SizedBox(height: 16),
              _greetingBar(),
              const SizedBox(height: 12),
              _balanceCard(),
              const SizedBox(height: 12),
              _inOutRow(),
              const SizedBox(height: 12),
              _walletCard(),
              const SizedBox(height: 12),
              _quickRecordCard(),
              const SizedBox(height: 12),
              if (_isOwner) ...[
                _chartCard(),
                const SizedBox(height: 12),
              ],
              _categoryRecapCard(),
              const SizedBox(height: 12),
              _recentTransactionsCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ---- potongan UI ----

  BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Colors.grey.withOpacity(0.15)),
  );

  Widget _header() {
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: _blue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.account_balance_wallet,
              color: Colors.white, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _storeName.isNotEmpty ? _storeName : 'CashMate UMKM',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600),
              ),
              const Text('Beranda',
                  style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        _circleButton(
          icon: Icons.notifications_none,
          onTap: _showActivitySheet,
          showDot: _transactions.isNotEmpty,
        ),
        const SizedBox(width: 8),
        _circleButton(icon: Icons.refresh, onTap: _loadAll),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    bool showDot = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 20),
            if (showDot)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  height: 7,
                  width: 7,
                  decoration: const BoxDecoration(
                      color: _amber, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _greetingBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: _cardDecoration(context),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Selamat datang, $_firstName!',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.circle, size: 7, color: _green),
                const SizedBox(width: 5),
                Text(_isOwner ? 'Pemilik Toko' : 'Kasir Aktif',
                    style: const TextStyle(
                        fontSize: 11,
                        color: _green,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _balanceCard() {
    final bool positif = _netCashflow >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B47B8), Color(0xFF2B7BF3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.savings_outlined,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: 8),
              const Text('Saldo Saat Ini',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              InkWell(
                onTap: () =>
                    setState(() => _balanceVisible = !_balanceVisible),
                child: Icon(
                  _balanceVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            !_isOwner
                ? 'Disembunyikan'
                : (_balanceVisible ? _rp(_totalBalance) : 'Rp ••••••••'),
            style: const TextStyle(
                fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      positif ? Icons.trending_up : Icons.trending_down,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isOwner ? _rpShort(_netCashflow) : '—',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('arus kas bersih bulan ini',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inOutRow() {
    return Row(
      children: [
        Expanded(
          child: _miniStat(
            label: 'Uang Masuk',
            value: _rp(_monthIncome),
            caption: 'Total $_incomeCount transaksi',
            icon: Icons.arrow_downward,
            color: _green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _miniStat(
            label: 'Uang Keluar',
            value: _rp(_monthExpense),
            caption: 'Total $_expenseCount transaksi',
            icon: Icons.arrow_upward,
            color: _red,
          ),
        ),
      ],
    );
  }

  Widget _miniStat({
    required String label,
    required String value,
    required String caption,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Text(caption,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  /// Kartu "Dompet & Kantong" — sebelumnya jadi tab sendiri di bottom nav,
  /// sekarang tinggal di Beranda sesuai permintaan.
  Widget _walletCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final total = _wallets.fold<double>(
      0,
          (sum, w) => sum + _toDouble(w['balance']),
    );
    final preview = _wallets.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : _indigoSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? theme.dividerColor.withOpacity(0.2) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.savings,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dompet & Kantong',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color)),
                    Text(
                      _wallets.isEmpty
                          ? 'Belum ada kantong kas'
                          : '${_wallets.length} kantong terpisah',
                      style: TextStyle(
                          fontSize: 11, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              if (_isOwner)
                Text(_rpShort(total),
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _amber)),
            ],
          ),
          if (preview.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (int i = 0; i < preview.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preview[i]['name']?.toString() ?? 'Kantong',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 11, color: theme.hintColor),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          preview[i].containsKey('balance')
                              ? _rpShort(_toDouble(preview[i]['balance']))
                              : '••••',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 12),
          InkWell(
            onTap: _openWalletPage,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'Kelola pembagian kas toko',
                  style: TextStyle(
                      fontSize: 12,
                      color: _blue,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 14, color: _blue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickRecordCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? theme.cardColor : _blueSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? theme.dividerColor.withOpacity(0.2) : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pencatatan instan',
                    style: TextStyle(
                        fontSize: 10,
                        color: _blue,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4)),
                const SizedBox(height: 4),
                Text('Kelola arus kas lebih cepat',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              elevation: 0,
              shape: const StadiumBorder(),
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: _openTransactionPage,
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: const Text('Catat',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _chartCard() {
    final series = _buildChartSeries();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Grafik keuangan',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('Tren pemasukan vs pengeluaran',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _blueSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${DateTime.now().year}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: _blue,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _legendDot(_blue, 'Pemasukan'),
              const SizedBox(width: 16),
              _legendDot(_amber, 'Pengeluaran'),
            ],
          ),
          const SizedBox(height: 14),
          if (series.isEmpty)
            const SizedBox(
              height: 140,
              child: Center(
                child: Text('Belum ada data laporan bulanan',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: CustomPaint(
                size: Size.infinite,
                painter: _MiniLineChartPainter(
                  series: series,
                  labels: _chartLabels(),
                  labelColor: Colors.grey,
                  gridColor: Colors.grey.withOpacity(0.25),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  /// Ambil 6 bulan terakhir dari GET /reports/monthly?year=…
  /// Field yang dijamin ada di Postman hanya `net_cashflow`; income/expense
  /// dibaca kalau backend memang mengirimnya, kalau tidak grafik jatuh ke
  /// satu garis arus kas bersih.
  List<_ChartSeries> _buildChartSeries() {
    if (_monthlyReport.isEmpty) return [];

    final currentMonth = DateTime.now().month;
    final start = math.max(0, currentMonth - 6);
    final slice = _monthlyReport.sublist(
      math.min(start, _monthlyReport.length),
      math.min(currentMonth, _monthlyReport.length),
    );
    if (slice.isEmpty) return [];

    double pick(Map<String, dynamic> row, List<String> keys) {
      for (final k in keys) {
        if (row[k] != null) return _toDouble(row[k]);
      }
      return double.nan;
    }

    final income = slice
        .map((r) => pick(r, ['income', 'total_income', 'current_month_income']))
        .toList();
    final expense = slice
        .map((r) =>
        pick(r, ['expense', 'total_expense', 'current_month_expense']))
        .toList();

    final hasDetail =
        income.every((v) => !v.isNaN) && expense.every((v) => !v.isNaN);

    if (hasDetail) {
      return [
        _ChartSeries(values: income, color: _blue, filled: true),
        _ChartSeries(values: expense, color: _amber, filled: false),
      ];
    }

    final net = slice.map((r) => _toDouble(r['net_cashflow'])).toList();
    return [_ChartSeries(values: net, color: _blue, filled: true)];
  }

  List<String> _chartLabels() {
    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final currentMonth = DateTime.now().month;
    final start = math.max(0, currentMonth - 6);
    return names.sublist(start, currentMonth);
  }

  Widget _categoryRecapCard() {
    final now = DateTime.now();
    final Map<String, double> byCategory = {};
    for (final t in _transactions) {
      final date = _dateOf(t);
      if (date == null || date.year != now.year || date.month != now.month) {
        continue;
      }
      final name = _categoryNameOf(t);
      byCategory[name] = (byCategory[name] ?? 0) + _toDouble(t['amount']);
    }

    final entries = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(3).toList();
    final total = entries.fold<double>(0, (s, e) => s + e.value);
    const palette = [_amber, _blue, _green];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rekap kategori',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('Alokasi kas toko bulan ini',
                        style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Text(_rpShort(total),
                  style: const TextStyle(
                      fontSize: 12,
                      color: _blue,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Belum ada transaksi bulan ini',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            )
          else
            for (int i = 0; i < top.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _categoryBar(
                name: top[i].key,
                amount: top[i].value,
                ratio: total == 0 ? 0 : top[i].value / total,
                color: palette[i % palette.length],
              ),
            ],
        ],
      ),
    );
  }

  Widget _categoryBar({
    required String name,
    required double amount,
    required double ratio,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              height: 8,
              width: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            Text(_rp(amount),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            SizedBox(
              width: 34,
              child: Text('${(ratio * 100).round()}%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.grey.withOpacity(0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _recentTransactionsCard() {
    final recent = _transactions.take(5).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Transaksi terbaru',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: _openTransactionPage,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: const Text('Lihat semua',
                    style: TextStyle(
                        fontSize: 12,
                        color: _blue,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('Belum ada transaksi tercatat',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            )
          else
            for (final t in recent) _transactionTile(t),
        ],
      ),
    );
  }

  Widget _transactionTile(Map<String, dynamic> t) {
    final isIncome = _isIncome(t);
    final color = isIncome ? _green : _red;
    final date = _dateOf(t);
    final title = (t['description'] ?? t['title'] ?? '').toString().isNotEmpty
        ? (t['description'] ?? t['title']).toString()
        : _categoryNameOf(t);

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
                isIncome ? Icons.south_west : Icons.north_east,
                size: 18,
                color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  date == null
                      ? _categoryNameOf(t)
                      : '${_categoryNameOf(t)} • ${_formatDate(date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isIncome ? '+' : '-'}${_rp(_toDouble(t['amount']))}',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  void _showActivitySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        final items = _transactions.take(8).toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Aktivitas terakhir',
                  style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Pencatatan kas terbaru dari server',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: Text('Belum ada aktivitas',
                        style: TextStyle(color: Colors.grey)),
                  ),
                )
              else
                for (final t in items) _transactionTile(t),
            ],
          ),
        );
      },
    );
  }
}

class _ChartSeries {
  final List<double> values;
  final Color color;
  final bool filled;

  const _ChartSeries({
    required this.values,
    required this.color,
    this.filled = false,
  });
}

/// Grafik garis sederhana tanpa dependency tambahan, supaya tampilannya
/// persis mengikuti mockup (kurva halus + area gradient + garis bantu putus-putus).
class _MiniLineChartPainter extends CustomPainter {
  final List<_ChartSeries> series;
  final List<String> labels;
  final Color labelColor;
  final Color gridColor;

  _MiniLineChartPainter({
    required this.series,
    required this.labels,
    required this.labelColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty || series.first.values.isEmpty) return;

    const double labelHeight = 22;
    final double chartHeight = size.height - labelHeight;
    if (chartHeight <= 0) return;

    double maxValue = 0;
    double minValue = 0;
    for (final s in series) {
      for (final v in s.values) {
        if (v > maxValue) maxValue = v;
        if (v < minValue) minValue = v;
      }
    }
    if (maxValue == minValue) maxValue = minValue + 1;
    final double range = maxValue - minValue;

    // Garis bantu horizontal
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final y = chartHeight * i / 3;
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final int count = series.first.values.length;
    final double stepX =
    count <= 1 ? size.width : size.width / (count - 1);

    for (final s in series) {
      final points = <Offset>[];
      for (int i = 0; i < s.values.length; i++) {
        final ratio = (s.values[i] - minValue) / range;
        points.add(Offset(
          i * stepX,
          chartHeight - (ratio * (chartHeight - 12)) - 6,
        ));
      }
      if (points.isEmpty) continue;

      final path = _smoothPath(points);

      if (s.filled) {
        final fillPath = Path.from(path)
          ..lineTo(points.last.dx, chartHeight)
          ..lineTo(points.first.dx, chartHeight)
          ..close();
        canvas.drawPath(
          fillPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                s.color.withOpacity(0.22),
                s.color.withOpacity(0.0),
              ],
            ).createShader(Rect.fromLTWH(0, 0, size.width, chartHeight)),
        );
      }

      canvas.drawPath(
        path,
        Paint()
          ..color = s.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round,
      );

      // Titik penanda pada bulan terakhir
      final last = points.last;
      canvas.drawCircle(last, 5, Paint()..color = s.color);
      canvas.drawCircle(last, 2.4, Paint()..color = Colors.white);
    }

    // Label bulan
    for (int i = 0; i < labels.length && i < count; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(fontSize: 10, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      double x = i * stepX - tp.width / 2;
      x = x.clamp(0.0, math.max(0.0, size.width - tp.width));
      tp.paint(canvas, Offset(x, chartHeight + 6));
    }
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }
    return path;
  }

  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 5.0;
    double x = start.dx;
    while (x < end.dx) {
      canvas.drawLine(
        Offset(x, start.dy),
        Offset(math.min(x + dashWidth, end.dx), end.dy),
        paint,
      );
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _MiniLineChartPainter oldDelegate) => true;
}