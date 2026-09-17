import 'package:flutter/material.dart';
import '../../models/transaction.dart';
import '../../models/wallet.dart';
import '../../models/category.dart';
import '../../services/api_service.dart';
import 'category_page.dart';
import 'wallet_page.dart';
import '../add_transaction_page.dart';

class TransactionPage extends StatefulWidget {
  final int userId;

  const TransactionPage({super.key, required this.userId});

  @override
  State<TransactionPage> createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  static const _primaryBlue = Color(0xFF0052CC);

  final searchController = TextEditingController();

  String filterType = 'Semua';
  bool isLoading = false;
  List<Transaction> transactions = [];
  List<Map<String, dynamic>> rawTransactions = [];

  List<Wallet> wallets = [];
  List<Category> categories = [];
  List<Map<String, dynamic>> rawWallets = [];
  List<Map<String, dynamic>> rawCategories = [];
  bool isLoadingMasterData = true;

  bool isOwner = true;

  static const _monthNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  static const _filterOptions = ['Semua', 'Uang Masuk', 'Uang Keluar', 'Bulan Ini'];

  @override
  void initState() {
    super.initState();
    fetchTransactions();
    fetchMasterData();
    _loadUserRole();
    searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final owner = await ApiService.isOwner();
    if (mounted) setState(() => isOwner = owner);
  }

  Future<void> fetchMasterData() async {
    setState(() => isLoadingMasterData = true);
    try {
      final walletData = await ApiService.fetchWallets();
      final categoryData = await ApiService.fetchCategories();

      final fetchedWallets = walletData.map((json) => Wallet.fromJson(json)).toList();
      final fetchedCategories = categoryData.map((json) => Category.fromJson(json)).toList();

      setState(() {
        wallets = fetchedWallets;
        categories = fetchedCategories;
        rawWallets = walletData;
        rawCategories = categoryData;
      });
    } catch (e) {
      debugPrint('Error fetchMasterData: $e');
    } finally {
      if (mounted) setState(() => isLoadingMasterData = false);
    }
  }

  Future<void> fetchTransactions() async {
    setState(() => isLoading = true);
    try {
      String? apiType;
      if (filterType == 'Uang Masuk') apiType = 'income';
      if (filterType == 'Uang Keluar') apiType = 'expense';

      final result = await ApiService.fetchTransactions(type: apiType, perPage: 100);
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(result['data'] ?? []);

      setState(() {
        rawTransactions = data;
        transactions = data.map((json) => Transaction.fromJson(json)).toList();
      });
    } catch (e) {
      debugPrint('Error fetching: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _onFilterChanged(String value) async {
    if (filterType == value) return;
    setState(() => filterType = value);
    await fetchTransactions();
  }

  Future<void> _voidTransaction(Map<String, dynamic> raw) async {
    final id = int.tryParse(raw['id'].toString());
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan Transaksi'),
        content: Text('Batalkan transaksi "${(raw['description']?.toString().trim().isNotEmpty ?? false) ? raw['description'] : 'ini'}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Batalkan', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ApiService.voidTransaction(id);
    if (!mounted) return;

    if (result['success'] == true) {
      await fetchTransactions();
      await fetchMasterData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Transaksi dibatalkan'),
          action: SnackBarAction(
            label: 'PULIHKAN',
            onPressed: () async {
              final restoreResult = await ApiService.restoreTransaction(id);
              if (restoreResult['success'] == true) {
                await fetchTransactions();
                await fetchMasterData();
              }
            },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Gagal membatalkan transaksi')),
      );
    }
  }

  Future<void> _startEditTransaction(Map<String, dynamic> raw) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTransactionPage(initialTransaction: raw)),
    );
    if (result == true) {
      await fetchTransactions();
      await fetchMasterData();
    }
  }

  Future<void> _openAddTransactionPage() async {
    if (isLoadingMasterData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sedang memuat data wallet & kategori, tunggu sebentar...')),
      );
      return;
    }

    if (wallets.isEmpty) {
      if (isOwner) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Belum ada wallet. Buat wallet terlebih dahulu.'), backgroundColor: Colors.orange),
        );
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletPage()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet belum tersedia. Minta Owner untuk membuat wallet terlebih dahulu.')),
        );
      }
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionPage()),
    );
    if (result == true) {
      await fetchTransactions();
      await fetchMasterData();
    }
  }

  void _showRecentActivitiesBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<List<dynamic>>(
          future: ApiService.fetchRecentActivities(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator()));
            }
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const SizedBox(height: 200, child: Center(child: Text('Belum ada aktivitas terbaru')));
            }

            final activities = snapshot.data!;
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Aktivitas Terakhir', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        final item = activities[index];
                        final bool isIncome = item['type'] == 'Cash In' || item['type'] == 'income';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isIncome ? Colors.green.shade100 : Colors.red.shade100,
                            child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward, color: isIncome ? Colors.green : Colors.red),
                          ),
                          title: Text(item['title'] ?? item['description'] ?? 'Transaksi'),
                          subtitle: Text(item['created_at'] ?? ''),
                          trailing: Text(
                            '${isIncome ? "+" : "-"} Rp ${item["amount"]}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.red),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  double get totalCashIn => filteredTransactions
      .where((x) => x.type == 'Cash In' || x.type == 'income')
      .fold(0, (sum, x) => sum + x.amount);

  double get totalCashOut => filteredTransactions
      .where((x) => x.type == 'Cash Out' || x.type == 'expense')
      .fold(0, (sum, x) => sum + x.amount);

  double get netBalance => totalCashIn - totalCashOut;

  List<Transaction> get filteredTransactions {
    final now = DateTime.now();
    final query = searchController.text.toLowerCase().trim();
    final result = <Transaction>[];

    for (int i = 0; i < transactions.length; i++) {
      final x = transactions[i];
      final raw = i < rawTransactions.length ? rawTransactions[i] : null;

      bool matchesType = true;
      if (filterType == 'Uang Masuk') matchesType = (x.type == 'Cash In' || x.type == 'income');
      if (filterType == 'Uang Keluar') matchesType = (x.type == 'Cash Out' || x.type == 'expense');
      if (filterType == 'Bulan Ini') {
        matchesType = (x.date.month == now.month && x.date.year == now.year);
      }

      final matchesSearch = query.isEmpty ||
          _displayTitle(x, raw).toLowerCase().contains(query) ||
          (_walletName(raw)?.toLowerCase().contains(query) ?? false);

      if (matchesType && matchesSearch) result.add(x);
    }
    return result;
  }

  String _formatRupiah(double amount) {
    String str = amount.toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String result = str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return 'Rp $result';
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_monthNames[d.month]} ${d.year}';

  String? _walletName(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final walletId = raw['wallet_id']?.toString();
    if (walletId == null) return null;
    final match = rawWallets.firstWhere((w) => w['id'].toString() == walletId, orElse: () => <String, dynamic>{});
    return match.isEmpty ? null : (match['name']?.toString());
  }

  Map<String, dynamic>? _categoryOf(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    final categoryId = raw['category_id']?.toString();
    if (categoryId == null) return null;
    final match = rawCategories.firstWhere((c) => c['id'].toString() == categoryId, orElse: () => <String, dynamic>{});
    return match.isEmpty ? null : match;
  }

  String _displayTitle(Transaction item, Map<String, dynamic>? raw) {
    final desc = raw?['description']?.toString().trim();
    if (desc != null && desc.isNotEmpty) return desc;

    final titleFromModel = item.title.trim();
    if (titleFromModel.isNotEmpty) return titleFromModel;

    final categoryName = _categoryOf(raw)?['name']?.toString();
    if (categoryName != null && categoryName.isNotEmpty) {
      final bool isIncome = item.type == 'Cash In' || item.type == 'income';
      return '${isIncome ? 'Pemasukan' : 'Pengeluaran'} • $categoryName';
    }

    return 'Transaksi Tanpa Keterangan';
  }

  static const List<Color> _categoryPalette = [
    Color(0xFF0052CC), Color(0xFF00875A), Color(0xFFDE350B), Color(0xFF6554C0),
    Color(0xFFFF8B00), Color(0xFF00A3BF), Color(0xFFC9372C), Color(0xFF5243AA),
    Color(0xFF008DA6), Color(0xFF974F0C),
  ];

  Color _categoryColor(String name) {
    final int hash = name.trim().toLowerCase().codeUnits.fold(0, (sum, c) => sum + c);
    return _categoryPalette[hash % _categoryPalette.length];
  }

  String _categoryInitial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: theme.cardColor,
        elevation: 0.5,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _primaryBlue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CASHMATE UMKM', style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.bold)),
                Text('Transaksi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_none, color: theme.iconTheme.color),
            onPressed: _showRecentActivitiesBottomSheet,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.blue.shade100,
              child: const Icon(Icons.person, size: 16, color: Colors.blue),
            ),
          )
        ],
      ),
      // Mengembalikan FAB dengan posisi dinaikkan (margin bottom) agar tidak tertutup bottom navigation bar
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton.extended(
          heroTag: 'fab_transaction_page',
          onPressed: _openAddTransactionPage,
          backgroundColor: _primaryBlue,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Catat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await fetchTransactions();
          await fetchMasterData();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 130), // Padding bawah diperbesar agar list terakhir tidak tertutup FAB/nav
          children: [
            _buildBalanceHeroCard(),
            const SizedBox(height: 14),
            _buildSearchField(theme),
            const SizedBox(height: 10),
            _buildFilterChips(theme),
            const SizedBox(height: 14),
            _buildListHeader(theme),
            const SizedBox(height: 8),
            if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filteredTransactions.isEmpty)
              _buildEmptyState(theme)
            else
              ...filteredTransactions.map((item) {
                final int originalIndex = transactions.indexOf(item);
                final Map<String, dynamic>? raw = (originalIndex >= 0 && originalIndex < rawTransactions.length)
                    ? rawTransactions[originalIndex]
                    : null;
                return _buildTransactionTile(item, raw, theme);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primaryBlue, Color(0xFF2E7BF5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primaryBlue.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Saldo Kas (sesuai filter)',
              style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            _formatRupiah(netBalance),
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _heroStat(
                  icon: Icons.arrow_downward,
                  iconColor: Colors.greenAccent.shade100,
                  label: 'Uang Masuk',
                  value: _formatRupiah(totalCashIn),
                ),
              ),
              Container(width: 1, height: 34, color: Colors.white24),
              const SizedBox(width: 12),
              Expanded(
                child: _heroStat(
                  icon: Icons.arrow_upward,
                  iconColor: Colors.redAccent.shade100,
                  label: 'Uang Keluar',
                  value: _formatRupiah(totalCashOut),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroStat({required IconData icon, required Color iconColor, required String label, required String value}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: searchController,
        style: TextStyle(fontSize: 13.5, color: theme.textTheme.bodyLarge?.color),
        decoration: InputDecoration(
          hintText: 'Cari transaksi (contoh: penjualan, gaji)...',
          hintStyle: TextStyle(fontSize: 12.5, color: theme.hintColor),
          prefixIcon: const Icon(Icons.search, size: 20, color: _primaryBlue),
          suffixIcon: searchController.text.isEmpty
              ? null
              : IconButton(
            icon: Icon(Icons.close, size: 18, color: theme.hintColor),
            onPressed: () => setState(searchController.clear),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFilterChips(ThemeData theme) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filterOptions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final option = _filterOptions[i];
          final bool selected = filterType == option;
          return GestureDetector(
            onTap: () => _onFilterChanged(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? _primaryBlue : theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? _primaryBlue : theme.dividerColor.withOpacity(0.2),
                ),
              ),
              child: Center(
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : theme.textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Riwayat Transaksi (${filteredTransactions.length})',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyLarge?.color),
        ),
        Text(
          'Ketuk: edit • Tekan lama: batalkan',
          style: TextStyle(fontSize: 10.5, color: theme.hintColor),
        ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final bool isSearching = searchController.text.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.receipt_long_outlined,
              size: 42,
              color: theme.hintColor,
            ),
            const SizedBox(height: 10),
            Text(
              isSearching ? 'Transaksi tidak ditemukan' : 'Belum ada transaksi',
              style: TextStyle(fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
            ),
            const SizedBox(height: 4),
            Text(
              isSearching
                  ? 'Coba kata kunci lain atau ubah filter.'
                  : 'Ketuk tombol "Catat" untuk menambah transaksi pertama.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(Transaction item, Map<String, dynamic>? raw, ThemeData theme) {
    final bool isIncome = item.type == 'Cash In' || item.type == 'income';
    final category = _categoryOf(raw);
    final categoryName = category?['name']?.toString();
    final walletName = _walletName(raw);
    final displayTitle = _displayTitle(item, raw);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: raw == null ? null : () => _startEditTransaction(raw),
        onLongPress: raw == null ? null : () => _voidTransaction(raw),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: categoryName != null
                        ? _categoryColor(categoryName).withOpacity(0.15)
                        : (isIncome ? Colors.green.shade50 : Colors.red.shade50),
                    child: categoryName != null
                        ? Text(
                      _categoryInitial(categoryName),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: _categoryColor(categoryName),
                      ),
                    )
                        : Icon(
                      isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                      color: isIncome ? Colors.green : Colors.red,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: theme.textTheme.bodyLarge?.color)),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(_formatDate(item.date), style: TextStyle(fontSize: 11, color: theme.hintColor)),
                        if (walletName != null) ...[
                          Text('•', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark ? Colors.blue.shade900.withOpacity(0.4) : const Color(0xFFEEF1F8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(walletName,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _primaryBlue)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: isIncome ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${isIncome ? "+" : "-"} ${_formatRupiah(item.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: isIncome ? Colors.green.shade400 : Colors.red.shade400,
                      ),
                    ),
                  ),
                  if (raw != null)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.more_vert, size: 18, color: theme.hintColor),
                      onSelected: (value) {
                        if (value == 'edit') _startEditTransaction(raw);
                        if (value == 'void') _voidTransaction(raw);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'void', child: Text('Batalkan', style: TextStyle(color: Colors.red))),
                      ],
                    )
                  else
                    const SizedBox(width: 6),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}