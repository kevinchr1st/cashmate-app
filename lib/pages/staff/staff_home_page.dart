import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_section_header.dart';
import '../../widgets/transaction_tile.dart';
import '../add_transaction_page.dart';
import 'staff_profile_page.dart';
import 'widgets/staff_greeting_card.dart';
import 'widgets/staff_quick_actions.dart';
import 'widgets/staff_summary_card.dart';
import 'widgets/staff_wallet_strip.dart';

/// Dipakai navigasi Staff (setelah berhasil mencatat) untuk memaksa Beranda
/// dan Aktivitas memuat ulang datanya.
final ValueNotifier<int> staffRefreshNotifier = ValueNotifier<int>(0);

/// Beranda Staff CashMate:
/// identitas usaha, quick action catat transaksi, statistik input hari ini,
/// daftar kantong kas aktif, dan riwayat singkat catatan hari ini.
class StaffHomePage extends StatefulWidget {
  const StaffHomePage({super.key});

  @override
  State<StaffHomePage> createState() => _StaffHomePageState();
}

class _StaffHomePageState extends State<StaffHomePage> {
  String staffName = '';
  String businessName = '';
  String? staffPhotoUrl;
  String currentRole = '';

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
    staffRefreshNotifier.addListener(_loadAll);
  }

  @override
  void dispose() {
    staffRefreshNotifier.removeListener(_loadAll);
    super.dispose();
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
        currentRole = (user['role'] ?? '').toString().toUpperCase();
        final photo = (user['profile_photo'] ?? '').toString();
        if (photo.isNotEmpty) {
          staffPhotoUrl = ApiService.resolvePhotoUrl(photo);
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
    setState(() => activeWallets = wallets);
  }

  Future<void> _loadTodaySummary() async {
    final result = await ApiService.fetchTransactions(perPage: 50);
    if (!mounted) return;

    final list = result['data'] as List<dynamic>? ?? [];
    double inc = 0, exp = 0;
    for (final trx in list) {
      final amount = (trx['amount'] is num)
          ? (trx['amount'] as num).toDouble()
          : double.tryParse(trx['amount'].toString()) ?? 0;
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

  static double _amountOf(dynamic trx) {
    final v = (trx as Map)['amount'];
    return v is num ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
  }

  static bool _isIncome(dynamic trx) =>
      ((trx as Map)['type'] ?? '').toString() == 'income';

  /// Buka form catat transaksi dengan tipe sudah terpilih (income/expense)
  /// sesuai tombol aksi cepat yang ditekan Kasir.
  Future<void> _openAddTransactionPage(String type) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionPage(initialType: type),
      ),
    );
    if (result == true && mounted) {
      _loadAll();
    }
  }

  void _openProfile() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StaffProfilePage()),
    ).then((_) => _loadAll());
  }

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
              const SizedBox(height: AppSpacing.xl),
              StaffGreetingCard(
                name: staffName,
                storeName: businessName,
                photoUrl: staffPhotoUrl,
                onTapProfile: _openProfile,
              ),
              const SizedBox(height: AppSpacing.lg),
              StaffQuickActions(
                onIncome: () => _openAddTransactionPage('income'),
                onExpense: () => _openAddTransactionPage('expense'),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xxl),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                StaffSummaryCard(
                  income: todayIncome,
                  expense: todayExpense,
                  transactionCount: todayCount,
                ),
                const SizedBox(height: AppSpacing.lg),
                // RBAC: nominal saldo hanya untuk Owner. Staff hanya melihat
                // nama dompet + status (••••), tanpa nominal.
                StaffWalletStrip(
                  wallets: activeWallets,
                  showBalance: currentRole == 'OWNER',
                ),
                const SizedBox(height: AppSpacing.lg),
                _todayTransactionsCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final theme = Theme.of(context);
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
            errorBuilder: (_, __, ___) => const Icon(Icons.point_of_sale,
                color: AppColors.primary, size: 22),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                businessName.isNotEmpty ? businessName : 'CashMate UMKM',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Beranda Kasir',
                style: AppTextStyles.title.copyWith(
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: _loadAll,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: theme.cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border(context)),
              boxShadow: AppColors.softShadow(context),
            ),
            child: Icon(
              Icons.refresh_rounded,
              size: 20,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _todayTransactionsCard() {
    final recent = todayTransactions.take(5).toList();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Catatan input hari ini',
            trailing: recent.isEmpty
                ? null
                : Text(
                    '${recent.length} transaksi',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
          ),
          if (recent.isEmpty)
            const AppEmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'Belum ada transaksi hari ini',
              message: 'Gunakan tombol catat di bawah untuk mulai input kasir',
            )
          else
            for (final trx in recent)
              TransactionTile(
                item: TransactionItem(
                  title: _titleOf(trx),
                  subtitle: _subtitleOf(trx),
                  amount: _amountOf(trx),
                  isIncome: _isIncome(trx),
                ),
              ),
        ],
      ),
    );
  }

  static String _titleOf(dynamic trx) {
    final t = trx as Map;
    final desc = (t['description'] ?? '').toString();
    if (desc.isNotEmpty) return desc;
    final cat = t['category'];
    return cat is Map && cat['name'] != null ? cat['name'].toString() : 'Kasir';
  }

  static String _subtitleOf(dynamic trx) {
    final t = trx as Map;
    final cat = t['category'];
    final catName = cat is Map && cat['name'] != null
        ? cat['name'].toString()
        : 'Tanpa Kategori';
    final wallet = t['wallet'];
    final walletName = wallet is Map && wallet['name'] != null
        ? wallet['name'].toString()
        : 'Cash';
    return '$walletName • $catName';
  }
}
