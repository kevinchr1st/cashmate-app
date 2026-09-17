import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_section_header.dart';
import '../../widgets/transaction_tile.dart';
import 'transaction_page.dart';
import 'widgets/owner_balance_card.dart';
import 'widgets/owner_category_recap_card.dart';
import 'widgets/owner_finance_chart_card.dart';
import 'widgets/owner_quick_action_card.dart';
import 'widgets/owner_stat_cards.dart';
import 'widgets/owner_wallet_preview_card.dart';

/// Dipakai halaman lain (mis. setelah transaksi baru disimpan dari bottom nav)
/// untuk memaksa Beranda memuat ulang datanya tanpa harus pindah tab.
final ValueNotifier<int> dashboardRefreshNotifier = ValueNotifier<int>(0);

/// Dipakai Beranda untuk meminta bottom navigation berpindah ke tab
/// "Kantong Kas" — lebih baik daripada push halaman baru, karena Kantong
/// sekarang adalah tab tengah dan tidak punya tombol kembali.
final ValueNotifier<int> openKantongTabNotifier = ValueNotifier<int>(0);

/// Beranda Owner: halaman utama yang merangkai kartu-kartu dari
/// `owner/widgets/` dengan whitespace longgar dan bahasa desain konsisten.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  bool _balanceVisible = true;
  bool _isOwner = true;

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

    // Chart report + summary diambil tanpa syarat agar grafik 12 bulan
    // selalu punya data meski isOwner() sempat gagal/lambat.
    final results = await Future.wait<dynamic>([
      ApiService.fetchWallets(status: 'active'),
      ApiService.fetchCategories(status: 'active'),
      ApiService.fetchTransactions(perPage: 50),
      ApiService.getDashboardSummary(),
      ApiService.getMonthlyReport(year: DateTime.now().year),
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

    final summary = results[3] as Map<String, dynamic>?;
    if (_isOwner && summary != null) {
      _totalBalance = _toDouble(summary['total_balance']);
      _monthIncome = _toDouble(summary['current_month_income']);
      _monthExpense = _toDouble(summary['current_month_expense']);
      _netCashflow = _toDouble(summary['net_cashflow']);
    } else {
      _computeSummaryLocally();
    }
    _monthlyReport = List<Map<String, dynamic>>.from(results[4] as List);

    _countThisMonthTransactions();
    setState(() => _isLoading = false);
  }

  Future<void> _loadIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    final savedStore = prefs.getString('saved_store_name');
    if (savedStore != null && savedStore.isNotEmpty) _storeName = savedStore;

    final me = await ApiService.getCurrentUser();
    if (me == null) return;
    final business = me['business'];
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
          color: AppColors.primary,
          onRefresh: _loadAll,
          child: ListView(
            padding: AppSpacing.pagePadding,
            children: [
              _header(),
              const SizedBox(height: AppSpacing.lg),
              OwnerBalanceCard(
                totalBalance: _totalBalance,
                netCashflow: _netCashflow,
                balanceVisible: _balanceVisible,
                isOwner: _isOwner,
                onToggleVisibility: () =>
                    setState(() => _balanceVisible = !_balanceVisible),
              ),
              const SizedBox(height: AppSpacing.lg),
              OwnerStatCards(
                income: _monthIncome,
                expense: _monthExpense,
                incomeCount: _incomeCount,
                expenseCount: _expenseCount,
              ),
              const SizedBox(height: AppSpacing.lg),
              OwnerWalletPreviewCard(
                wallets: _wallets,
                total: _totalBalance,
                onManage: _openWalletPage,
              ),
              const SizedBox(height: AppSpacing.lg),
              OwnerQuickActionCard(onRecord: _openTransactionPage),
              if (_isOwner) ...[
                const SizedBox(height: AppSpacing.lg),
                OwnerFinanceChartCard(
                  report: _monthlyReport,
                  year: DateTime.now().year,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              _categoryRecapCard(),
              const SizedBox(height: AppSpacing.lg),
              _recentTransactionsCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ---- potongan UI ----

  Widget _header() {
    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Image.asset(
            'assets/cashmate-logo.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(
              Icons.account_balance_wallet,
              color: AppColors.primary,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _storeName.isNotEmpty ? _storeName : 'CashMate UMKM',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Beranda',
                style: AppTextStyles.title.copyWith(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
        _circleButton(
          icon: Icons.notifications_none_rounded,
          onTap: _showActivitySheet,
          showDot: _transactions.isNotEmpty,
        ),
        const SizedBox(width: AppSpacing.sm),
        _circleButton(
          icon: Icons.refresh_rounded,
          onTap: _loadAll,
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    bool showDot = false,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: theme.cardColor,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border(context)),
          boxShadow: AppColors.softShadow(context),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              icon,
              size: 20,
              color: theme.textTheme.bodyLarge?.color,
            ),
            if (showDot)
              Positioned(
                right: -1,
                top: -1,
                child: Container(
                  height: 7,
                  width: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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
    const palette = [AppColors.accent, AppColors.primary, AppColors.success];

    return OwnerCategoryRecapCard(
      total: total,
      slices: [
        for (int i = 0; i < top.length; i++)
          CategorySlice(
            name: top[i].key,
            amount: top[i].value,
            ratio: total == 0 ? 0 : top[i].value / total,
            color: palette[i % palette.length],
          ),
      ],
    );
  }

  Widget _recentTransactionsCard() {
    final recent = _transactions.take(5).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Transaksi terbaru',
            trailing: TextButton(
              onPressed: _openTransactionPage,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Lihat semua',
                style: AppTextStyles.subheading.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (recent.isEmpty)
            const AppEmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'Belum ada transaksi tercatat',
            )
          else
            for (final t in recent) _transactionTile(t),
        ],
      ),
    );
  }

  Widget _transactionTile(Map<String, dynamic> t) {
    final isIncome = _isIncome(t);
    final date = _dateOf(t);
    final title = (t['description'] ?? t['title'] ?? '').toString().isNotEmpty
        ? (t['description'] ?? t['title']).toString()
        : _categoryNameOf(t);
    final subtitle = date == null
        ? _categoryNameOf(t)
        : '${_categoryNameOf(t)} • ${AppDate.short(date)}';

    return TransactionTile(
      item: TransactionItem(
        title: title,
        subtitle: subtitle,
        amount: _toDouble(t['amount']),
        isIncome: isIncome,
      ),
    );
  }

  void _showActivitySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      // Biarkan konten memakai layar penuh; SingleChildScrollView mencegah
      // "BOTTOM OVERFLOWED" saat daftar aktivitas lebih tinggi dari layar.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) {
        final items = _transactions.take(8).toList();
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              18,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionHeader(
                  title: 'Aktivitas terakhir',
                  subtitle: 'Pencatatan kas terbaru dari server',
                  padding: EdgeInsets.zero,
                ),
                if (items.isEmpty)
                  const AppEmptyState(
                    icon: Icons.inbox_rounded,
                    title: 'Belum ada aktivitas',
                  )
                else
                  for (final t in items) _transactionTile(t),
              ],
            ),
          ),
        );
      },
    );
  }
}
