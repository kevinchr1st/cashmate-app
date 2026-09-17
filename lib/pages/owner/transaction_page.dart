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

  // Status filter: active (default), all, disabled (void)
  String _statusFilter = 'active';
  // Type filter: null (semua), income, expense
  String? _typeFilter;

  bool isLoading = false;
  List<Transaction> transactions = [];
  List<Map<String, dynamic>> rawTransactions = [];

  // Transaksi aktif terpisah untuk menghitung total (tidak pernah menjumlah void)
  List<Transaction> _activeTransactions = [];

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

  @override
  void initState() {
    super.initState();
    _fetchData();
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

  Future<void> _fetchData() async {
    await Future.wait([fetchTransactions(), fetchMasterData(), _fetchActiveTransactions()]);
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
      final result = await ApiService.fetchTransactions(
        status: _statusFilter,
        type: _typeFilter,
        perPage: 100,
      );
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

  /// Fetch transaksi aktif terpisah untuk menghitung total, agar void
  /// tidak pernah masuk hitungan meskipun filter sedang menampilkan Semua/Void.
  Future<void> _fetchActiveTransactions() async {
    try {
      final result = await ApiService.fetchTransactions(status: 'active', perPage: 100);
      final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(result['data'] ?? []);
      if (mounted) {
        setState(() {
          _activeTransactions = data.map((json) => Transaction.fromJson(json)).toList();
        });
      }
    } catch (e) {
      debugPrint('Error _fetchActiveTransactions: $e');
    }
  }

  Future<void> _onStatusFilterChanged(String value) async {
    if (_statusFilter == value) return;
    setState(() => _statusFilter = value);
    await fetchTransactions();
  }

  Future<void> _onTypeFilterChanged(String? value) async {
    if (_typeFilter == value) return;
    setState(() => _typeFilter = value);
    await fetchTransactions();
  }

  Future<void> _voidTransaction(Transaction trx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Void Transaksi'),
        content: Text('Void transaksi "${trx.displayTitle}"? Efek saldo akan dibalik.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Void', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ApiService.voidTransaction(trx.id);
    if (!mounted) return;

    if (result['success'] == true) {
      await _refreshAll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Transaksi di-void'),
          action: SnackBarAction(
            label: 'PULIHKAN',
            onPressed: () => _restoreTransaction(trx.id),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Gagal void transaksi')),
      );
    }
  }

  Future<void> _restoreTransaction(int transactionId) async {
    final result = await ApiService.restoreTransaction(transactionId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['success'] == true
          ? (result['message'] ?? 'Transaksi dipulihkan')
          : (result['message'] ?? 'Gagal memulihkan transaksi'))),
    );
    if (result['success'] == true) await _refreshAll();
  }

  Future<void> _refreshAll() async {
    await Future.wait([fetchTransactions(), fetchMasterData(), _fetchActiveTransactions()]);
  }

  Future<void> _startEditTransaction(Transaction trx) async {
    // Reconstruct raw map for AddTransactionPage
    final rawIndex = transactions.indexOf(trx);
    final Map<String, dynamic>? raw = (rawIndex >= 0 && rawIndex < rawTransactions.length)
        ? rawTransactions[rawIndex]
        : null;
    if (raw == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddTransactionPage(initialTransaction: raw)),
    );
    if (result == true) await _refreshAll();
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
    if (result == true) await _refreshAll();
  }

  // ---- Totals hanya dari transaksi AKTIF ----
  double get totalCashIn => _activeTransactions
      .where((x) => x.type == 'income')
      .fold(0, (sum, x) => sum + x.amount);

  double get totalCashOut => _activeTransactions
      .where((x) => x.type == 'expense')
      .fold(0, (sum, x) => sum + x.amount);

  double get netBalance => totalCashIn - totalCashOut;

  List<Transaction> get filteredTransactions {
    final query = searchController.text.toLowerCase().trim();
    if (query.isEmpty) return transactions;

    return transactions.where((trx) {
      return trx.displayTitle.toLowerCase().contains(query) ||
          (trx.wallet?.name.toLowerCase().contains(query) ?? false) ||
          (trx.category?.name.toLowerCase().contains(query) ?? false) ||
          (trx.createdBy?.name.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  String _formatRupiah(double amount) {
    String str = amount.toStringAsFixed(0);
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String result = str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return 'Rp $result';
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_monthNames[d.month]} ${d.year}';

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
      ),
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
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
          children: [
            _buildBalanceHeroCard(),
            const SizedBox(height: 14),
            _buildSearchField(theme),
            const SizedBox(height: 10),
            // ---- Status filter ----
            _buildStatusFilterChips(theme),
            const SizedBox(height: 8),
            // ---- Type filter ----
            _buildTypeFilterChips(theme),
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
              ...filteredTransactions.map((trx) => _buildTransactionTile(trx, theme)),
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
          const Text('Saldo Kas (transaksi aktif)',
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
                  label: 'Pemasukan',
                  value: _formatRupiah(totalCashIn),
                ),
              ),
              Container(width: 1, height: 34, color: Colors.white24),
              const SizedBox(width: 12),
              Expanded(
                child: _heroStat(
                  icon: Icons.arrow_upward,
                  iconColor: Colors.redAccent.shade100,
                  label: 'Pengeluaran',
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
          hintText: 'Cari transaksi...',
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

  Widget _buildStatusFilterChips(ThemeData theme) {
    const options = [
      {'label': 'Aktif', 'value': 'active'},
      {'label': 'Semua', 'value': 'all'},
      {'label': 'Void', 'value': 'disabled'},
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final opt = options[i];
          final bool selected = _statusFilter == opt['value'];
          return GestureDetector(
            onTap: () => _onStatusFilterChanged(opt['value']!),
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
                  opt['label']!,
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

  Widget _buildTypeFilterChips(ThemeData theme) {
    const options = [
      {'label': 'Semua Jenis', 'value': null},
      {'label': 'Pemasukan', 'value': 'income'},
      {'label': 'Pengeluaran', 'value': 'expense'},
    ];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final opt = options[i];
          final bool selected = _typeFilter == opt['value'];
          final chipColor = opt['value'] == 'income'
              ? Colors.green
              : opt['value'] == 'expense'
              ? Colors.red
              : _primaryBlue;
          return GestureDetector(
            onTap: () => _onTypeFilterChanged(opt['value'] as String?),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? chipColor.withOpacity(0.15) : theme.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? chipColor : theme.dividerColor.withOpacity(0.2),
                ),
              ),
              child: Center(
                child: Text(
                  opt['label']!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? chipColor : theme.textTheme.bodyLarge?.color,
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
        if (_statusFilter != 'disabled')
          Text(
            'Ketuk: edit • Tekan lama: void',
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

  Widget _buildTransactionTile(Transaction trx, ThemeData theme) {
    final bool isIncome = trx.type == 'income';
    final categoryName = trx.category?.name;
    final walletName = trx.wallet?.name;
    final creatorName = trx.createdBy?.name;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: trx.isVoid ? theme.cardColor.withOpacity(0.6) : theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: trx.isVoid ? Colors.orange.withOpacity(0.3) : theme.dividerColor.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        // Aktif: tap=edit, long=void. Void: tap=restore
        onTap: trx.isVoid ? () => _restoreTransaction(trx.id) : () => _startEditTransaction(trx),
        onLongPress: trx.isVoid ? null : () => _voidTransaction(trx),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: trx.isVoid
                        ? Colors.grey.withOpacity(0.15)
                        : categoryName != null
                        ? _categoryColor(categoryName).withOpacity(0.15)
                        : (isIncome ? Colors.green.shade50 : Colors.red.shade50),
                    child: trx.isVoid
                        ? const Icon(Icons.block, color: Colors.grey, size: 18)
                        : categoryName != null
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            trx.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5,
                              color: trx.isVoid ? theme.hintColor : theme.textTheme.bodyLarge?.color,
                              decoration: trx.isVoid ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (trx.isVoid) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'VOID',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(_formatDate(trx.dateTime), style: TextStyle(fontSize: 11, color: theme.hintColor)),
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
                        if (creatorName != null && creatorName.isNotEmpty) ...[
                          Text('•', style: TextStyle(fontSize: 11, color: theme.hintColor)),
                          Text(creatorName, style: TextStyle(fontSize: 10.5, color: theme.hintColor)),
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
                      color: trx.isVoid
                          ? Colors.grey.withOpacity(0.1)
                          : isIncome ? Colors.green.withOpacity(0.12) : Colors.red.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${isIncome ? "+" : "-"} ${_formatRupiah(trx.amount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: trx.isVoid
                            ? Colors.grey
                            : isIncome ? Colors.green.shade400 : Colors.red.shade400,
                      ),
                    ),
                  ),
                  if (!trx.isVoid)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.more_vert, size: 18, color: theme.hintColor),
                      onSelected: (value) {
                        if (value == 'edit') _startEditTransaction(trx);
                        if (value == 'void') _voidTransaction(trx);
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'void', child: Text('Void', style: TextStyle(color: Colors.red))),
                      ],
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: IconButton(
                        icon: const Icon(Icons.restore, size: 20, color: Colors.green),
                        onPressed: () => _restoreTransaction(trx.id),
                        tooltip: 'Pulihkan',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}