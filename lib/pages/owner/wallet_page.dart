import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/api_service.dart'; // Naik dua level ke folder services/

/// Halaman "Kantong Kas" — tab tengah pada bottom navigation.
class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  static const Color _blue = Color(0xFF1155D9);
  static const Color _green = Color(0xFF12B76A);
  static const Color _red = Color(0xFFE5484D);
  static const Color _amber = Color(0xFFF5A524);

  static const List<Color> _palette = [
    _amber,
    Color(0xFFD97706),
    _blue,
    Color(0xFF3B82F6),
    _green,
    _red,
  ];

  static const List<IconData> _icons = [
    Icons.point_of_sale,
    Icons.inventory_2_outlined,
    Icons.groups_outlined,
    Icons.payments_outlined,
    Icons.savings_outlined,
    Icons.account_balance_outlined,
  ];

  bool _isLoading = true;
  bool _isOwner = true;
  bool _showDisabled = false;
  String _sortMode = 'Tertinggi';
  final TextEditingController _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _wallets = [];
  List<Map<String, dynamic>> _disabledWallets = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _transferHistory = [];
  final Map<int, double> _targets = {};

  static const String _transferTag = '[Pindah]';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    _isOwner = await ApiService.isOwner();

    final results = await Future.wait<dynamic>([
      ApiService.fetchWallets(status: 'active'),
      ApiService.fetchCategories(status: 'active'),
      ApiService.fetchTransactions(perPage: 50),
      if (_isOwner) ApiService.fetchWallets(status: 'disabled'),
    ]);

    if (!mounted) return;

    _wallets = List<Map<String, dynamic>>.from(results[0] as List);
    _categories = List<Map<String, dynamic>>.from(results[1] as List);

    final trx = results[2] as Map<String, dynamic>;
    final all = List<Map<String, dynamic>>.from(trx['data'] ?? []);
    _transferHistory = all
        .where((t) =>
        (t['description']?.toString() ?? '').startsWith(_transferTag))
        .toList();

    _disabledWallets = _isOwner
        ? List<Map<String, dynamic>>.from(results[3] as List)
        : [];

    await _loadTargets();

    setState(() => _isLoading = false);
  }

  Future<void> _loadTargets() async {
    final prefs = await SharedPreferences.getInstance();
    _targets.clear();
    for (final w in [..._wallets, ..._disabledWallets]) {
      final id = _idOf(w);
      if (id == null) continue;
      final value = prefs.getDouble('wallet_target_$id');
      if (value != null && value > 0) _targets[id] = value;
    }
  }

  static int? _idOf(Map<String, dynamic> w) =>
      int.tryParse(w['id']?.toString() ?? '');

  static double _toDouble(dynamic v) =>
      v == null ? 0 : (num.tryParse(v.toString())?.toDouble() ?? 0);

  double _balanceOf(Map<String, dynamic> w) => _toDouble(w['balance']);

  bool get _balanceHidden => !_isOwner;

  String _rp(double amount) {
    final negative = amount < 0;
    final str = amount.abs().toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return '${negative ? '-' : ''}Rp ${str.replaceAllMapped(reg, (m) => '${m[1]}.')}';
  }

  String _rpShort(double amount) {
    if (amount.abs() >= 1000000000) {
      return 'Rp ${(amount / 1000000000).toStringAsFixed(2).replaceAll('.', ',')} M';
    }
    if (amount.abs() >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(2).replaceAll('.', ',')} Jt';
    }
    return _rp(amount);
  }

  double get _totalBalance =>
      _wallets.fold<double>(0, (s, w) => s + _balanceOf(w));

  List<Map<String, dynamic>> get _visibleWallets {
    final source = _showDisabled ? _disabledWallets : _wallets;
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = source.where((w) {
      if (query.isEmpty) return true;
      return (w['name']?.toString().toLowerCase() ?? '').contains(query);
    }).toList();

    switch (_sortMode) {
      case 'Terendah':
        filtered.sort((a, b) => _balanceOf(a).compareTo(_balanceOf(b)));
        break;
      case 'Nama':
        filtered.sort((a, b) => (a['name']?.toString() ?? '')
            .toLowerCase()
            .compareTo((b['name']?.toString() ?? '').toLowerCase()));
        break;
      default:
        filtered.sort((a, b) => _balanceOf(b).compareTo(_balanceOf(a)));
    }
    return filtered;
  }

  List<Map<String, dynamic>> _categoriesOfType(String type) => _categories
      .where((c) => c['type']?.toString().toLowerCase() == type)
      .toList();

  void _toast(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  void _ownerOnly() =>
      _toast('Hanya pemilik toko yang bisa mengubah kantong kas.');

  Future<void> _showWalletFormDialog({Map<String, dynamic>? wallet}) async {
    if (!_isOwner) return _ownerOnly();

    final isEdit = wallet != null;
    final nameCtrl =
    TextEditingController(text: wallet?['name']?.toString() ?? '');
    final targetCtrl = TextEditingController(
      text: isEdit && _targets[_idOf(wallet)] != null
          ? _targets[_idOf(wallet)]!.toStringAsFixed(0)
          : '',
    );

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEdit ? 'Ubah kantong' : 'Buat kantong baru',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Nama kantong',
                  hintText: 'Contoh: Laci Kasir Utama',
                  prefixIcon: const Icon(Icons.savings_outlined, size: 20),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Target / batas saldo (opsional)',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Target dipakai untuk bar progres di kartu kantong dan disimpan di perangkat ini saja.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _blue),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) {
                _toast('Nama kantong wajib diisi.');
                return;
              }
              Navigator.pop(dialogContext);

              Map<String, dynamic> result;
              if (isEdit) {
                result = await ApiService.updateWallet(
                  walletId: _idOf(wallet)!,
                  name: name,
                );
              } else {
                result = await ApiService.createWallet(name: name);
              }

              if (result['success'] != true) {
                _toast(result['message']?.toString() ?? 'Gagal menyimpan kantong.',
                    color: _red);
                return;
              }

              final target = double.tryParse(targetCtrl.text.trim());
              final id = isEdit
                  ? _idOf(wallet)
                  : int.tryParse((result['data']?['id'] ?? '').toString());
              if (id != null) {
                final prefs = await SharedPreferences.getInstance();
                if (target != null && target > 0) {
                  await prefs.setDouble('wallet_target_$id', target);
                } else {
                  await prefs.remove('wallet_target_$id');
                }
              }

              _toast(isEdit ? 'Kantong diperbarui.' : 'Kantong dibuat.',
                  color: _green);
              await _loadAll();
            },
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _showTopUpSheet(Map<String, dynamic> wallet) async {
    final incomeCategories = _categoriesOfType('income');
    if (incomeCategories.isEmpty) {
      _toast('Belum ada kategori pemasukan. Buat dulu lewat menu Toko.',
          color: _amber);
      return;
    }

    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    Map<String, dynamic> category = incomeCategories.first;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 26,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Isi saldo • ${wallet['name'] ?? 'Kantong'}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              const Text('Tercatat sebagai pemasukan pada buku kas toko.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 18),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Nominal',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Map<String, dynamic>>(
                initialValue: category,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Kategori pemasukan',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: incomeCategories
                    .map((c) => DropdownMenuItem<Map<String, dynamic>>(
                  value: c,
                  child: Text(c['name']?.toString() ?? 'Kategori',
                      overflow: TextOverflow.ellipsis),
                ))
                    .toList(),
                onChanged: (v) =>
                    setSheetState(() => category = v ?? category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Keterangan (opsional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                    final amount =
                        double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (amount <= 0) {
                      _toast('Isi nominal terlebih dahulu.');
                      return;
                    }
                    setSheetState(() => saving = true);

                    final result = await ApiService.createTransaction(
                      walletId: _idOf(wallet)!,
                      categoryId: _idOf(category)!,
                      amount: amount,
                      type: 'income',
                      description: noteCtrl.text.trim().isEmpty
                          ? 'Isi saldo ${wallet['name']}'
                          : noteCtrl.text.trim(),
                    );

                    if (result['success'] == true) {
                      if (Navigator.canPop(sheetContext)) {
                        Navigator.pop(sheetContext);
                      }
                      _toast('Saldo kantong bertambah.', color: _green);
                      await _loadAll();
                    } else {
                      setSheetState(() => saving = false);
                      _toast(
                          result['message']?.toString() ??
                              'Gagal mengisi saldo.',
                          color: _red);
                    }
                  },
                  child: saving
                      ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text('Simpan',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTransferSheet({Map<String, dynamic>? from}) async {
    if (!_isOwner) return _ownerOnly();
    if (_wallets.length < 2) {
      _toast('Butuh minimal dua kantong aktif untuk memindahkan saldo.',
          color: _amber);
      return;
    }

    final incomeCategories = _categoriesOfType('income');
    final expenseCategories = _categoriesOfType('expense');
    if (incomeCategories.isEmpty || expenseCategories.isEmpty) {
      _toast(
          'Butuh satu kategori pemasukan dan satu kategori pengeluaran untuk mencatat mutasi.',
          color: _amber);
      return;
    }

    Map<String, dynamic> source = from ?? _wallets.first;
    Map<String, dynamic> target =
    _wallets.firstWhere((w) => _idOf(w) != _idOf(source));
    final amountCtrl = TextEditingController();
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 26,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pindah saldo antar kantong',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              const Text(
                  'Dicatat sebagai mutasi internal: keluar dari kantong asal, masuk ke kantong tujuan.',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 18),
              DropdownButtonFormField<Map<String, dynamic>>(
                initialValue: source,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Dari kantong',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: _wallets
                    .map((w) => DropdownMenuItem<Map<String, dynamic>>(
                  value: w,
                  child: Text(w['name']?.toString() ?? 'Kantong',
                      overflow: TextOverflow.ellipsis),
                ))
                    .toList(),
                onChanged: (v) => setSheetState(() {
                  source = v ?? source;
                  if (_idOf(source) == _idOf(target)) {
                    target = _wallets
                        .firstWhere((w) => _idOf(w) != _idOf(source));
                  }
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Map<String, dynamic>>(
                initialValue: target,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Ke kantong',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: _wallets
                    .where((w) => _idOf(w) != _idOf(source))
                    .map((w) => DropdownMenuItem<Map<String, dynamic>>(
                  value: w,
                  child: Text(w['name']?.toString() ?? 'Kantong',
                      overflow: TextOverflow.ellipsis),
                ))
                    .toList(),
                onChanged: (v) => setSheetState(() => target = v ?? target),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Nominal',
                  prefixText: 'Rp ',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                    final amount =
                        double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (amount <= 0) {
                      _toast('Isi nominal terlebih dahulu.');
                      return;
                    }
                    if (amount > _balanceOf(source)) {
                      _toast('Saldo kantong asal tidak mencukupi.',
                          color: _amber);
                      return;
                    }
                    setSheetState(() => saving = true);

                    final label =
                        '$_transferTag ${source['name']} > ${target['name']}';

                    final out = await ApiService.createTransaction(
                      walletId: _idOf(source)!,
                      categoryId: _idOf(expenseCategories.first)!,
                      amount: amount,
                      type: 'expense',
                      description: label,
                    );
                    if (out['success'] != true) {
                      setSheetState(() => saving = false);
                      _toast(
                          out['message']?.toString() ??
                              'Mutasi gagal dicatat.',
                          color: _red);
                      return;
                    }

                    final incoming =
                    await ApiService.createTransaction(
                      walletId: _idOf(target)!,
                      categoryId: _idOf(incomeCategories.first)!,
                      amount: amount,
                      type: 'income',
                      description: label,
                    );

                    if (Navigator.canPop(sheetContext)) {
                      Navigator.pop(sheetContext);
                    }

                    if (incoming['success'] == true) {
                      _toast('Saldo dipindahkan.', color: _green);
                    } else {
                      _toast(
                          'Dana keluar tercatat, tapi pemasukan di kantong tujuan gagal.',
                          color: _red);
                    }
                    await _loadAll();
                  },
                  child: saving
                      ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                      : const Text('Pindahkan',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDisable(Map<String, dynamic> wallet) async {
    if (!_isOwner) return _ownerOnly();
    final id = _idOf(wallet);
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nonaktifkan kantong?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
            '"${wallet['name']}" tidak akan muncul saat mencatat transaksi. Riwayat transaksinya tetap tersimpan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDEDEC), elevation: 0),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Nonaktifkan',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final ok = await ApiService.disableWallet(id);
    _toast(ok ? 'Kantong dinonaktifkan.' : 'Gagal menonaktifkan kantong.',
        color: ok ? null : _red);
    if (ok) await _loadAll();
  }

  Future<void> _restore(Map<String, dynamic> wallet) async {
    final id = _idOf(wallet);
    if (id == null) return;
    final ok = await ApiService.restoreWallet(id);
    _toast(ok ? 'Kantong diaktifkan kembali.' : 'Gagal mengaktifkan kantong.',
        color: ok ? _green : _red);
    if (ok) await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
          color: _blue,
          onRefresh: _loadAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              _header(),
              const SizedBox(height: 16),
              _titleRow(),
              const SizedBox(height: 12),
              _summaryCard(),
              const SizedBox(height: 14),
              _filterRow(),
              const SizedBox(height: 12),
              _searchRow(),
              const SizedBox(height: 14),
              ..._walletList(),
              const SizedBox(height: 14),
              if (_isOwner && !_showDisabled) _createCard(),
              const SizedBox(height: 16),
              if (!_balanceHidden) _allocationCard(),
              const SizedBox(height: 16),
              _historyCard(),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.15)),
  );

  Widget _header() {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
              color: _blue, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.savings, color: Colors.white, size: 21),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CashMate UMKM',
                  style: TextStyle(
                      fontSize: 11,
                      color: theme.hintColor,
                      fontWeight: FontWeight.w600)),
              Text('Kantong Kas',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color)),
            ],
          ),
        ),
        InkWell(
          onTap: _loadAll,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: theme.cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
            ),
            child: Icon(Icons.refresh, size: 20, color: theme.iconTheme.color),
          ),
        ),
      ],
    );
  }

  Widget _titleRow() {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dompet & kantong',
                  style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color)),
              const SizedBox(height: 3),
              Row(
                children: [
                  Container(
                    height: 7,
                    width: 7,
                    decoration: const BoxDecoration(
                        color: _blue, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(_isOwner ? 'Akses owner' : 'Akses kasir',
                      style: const TextStyle(
                          fontSize: 11,
                          color: _blue,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        if (_isOwner) ...[
          InkWell(
            onTap: () => _showTransferSheet(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? _blue.withOpacity(0.25)
                    : const Color(0xFFE8F0FE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.swap_horiz, size: 20, color: _blue),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _showWalletFormDialog(),
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: const Text('Kantong',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ],
    );
  }

  Widget _summaryCard() {
    final theme = Theme.of(context);
    final top = [..._wallets]
      ..sort((a, b) => _balanceOf(b).compareTo(_balanceOf(a)));
    final preview = top.take(3).toList();
    final total = _totalBalance;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Total dana terdistribusi',
                    style: TextStyle(
                        fontSize: 11,
                        color: theme.hintColor,
                        fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.circle, size: 7, color: _green),
                    SizedBox(width: 5),
                    Text('Saldo real-time',
                        style: TextStyle(
                            fontSize: 10,
                            color: _green,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _balanceHidden ? 'Disembunyikan' : _rp(total),
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: _blue),
          ),
          const SizedBox(height: 6),
          Text(
            '${_wallets.length} kantong aktif'
                '${_isOwner && _disabledWallets.isNotEmpty ? ' • ${_disabledWallets.length} nonaktif' : ''}',
            style: TextStyle(fontSize: 11, color: theme.hintColor),
          ),
          if (!_balanceHidden && preview.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                for (int i = 0; i < preview.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 7,
                              width: 7,
                              decoration: BoxDecoration(
                                  color: _palette[i % _palette.length],
                                  shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                preview[i]['name']?.toString() ?? 'Kantong',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10, color: theme.hintColor),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(_rpShort(_balanceOf(preview[i])),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: theme.textTheme.bodyLarge?.color)),
                        ),
                        Text(
                          total == 0
                              ? '0%'
                              : '${(_balanceOf(preview[i]) / total * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                              fontSize: 10, color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterRow() {
    if (!_isOwner) return const SizedBox.shrink();
    return Row(
      children: [
        _filterChip('Aktif (${_wallets.length})', !_showDisabled,
                () => setState(() => _showDisabled = false)),
        const SizedBox(width: 8),
        _filterChip('Nonaktif (${_disabledWallets.length})', _showDisabled,
                () => setState(() => _showDisabled = true)),
      ],
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _blue : theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? _blue : theme.dividerColor.withOpacity(0.25)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: selected ? Colors.white : theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _searchRow() {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: _cardDecoration,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: theme.textTheme.bodyLarge?.color),
              decoration: InputDecoration(
                hintText: 'Cari nama kantong kas',
                hintStyle: TextStyle(fontSize: 13, color: theme.hintColor),
                icon: Icon(Icons.search, size: 19, color: theme.hintColor),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        InkWell(
          onTap: () {
            const modes = ['Tertinggi', 'Terendah', 'Nama'];
            final next = (modes.indexOf(_sortMode) + 1) % modes.length;
            setState(() => _sortMode = modes[next]);
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: _cardDecoration,
            child: Row(
              children: [
                Icon(Icons.swap_vert, size: 17, color: theme.hintColor),
                const SizedBox(width: 4),
                Text(_sortMode,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _walletList() {
    final theme = Theme.of(context);
    final wallets = _visibleWallets;
    if (wallets.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 34),
          decoration: _cardDecoration,
          child: Column(
            children: [
              Icon(Icons.savings_outlined,
                  size: 34, color: theme.hintColor.withOpacity(0.5)),
              const SizedBox(height: 10),
              Text(
                _showDisabled
                    ? 'Tidak ada kantong nonaktif.'
                    : _searchCtrl.text.isNotEmpty
                    ? 'Kantong tidak ditemukan.'
                    : 'Belum ada kantong kas.',
                style: TextStyle(fontSize: 12, color: theme.hintColor),
              ),
            ],
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    for (int i = 0; i < wallets.length; i++) {
      if (i > 0) widgets.add(const SizedBox(height: 12));
      widgets.add(_walletCard(wallets[i], i));
    }
    return widgets;
  }

  Widget _walletCard(Map<String, dynamic> wallet, int index) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = _palette[index % _palette.length];
    final icon = _icons[index % _icons.length];
    final id = _idOf(wallet);
    final balance = _balanceOf(wallet);
    final target = id == null ? null : _targets[id];
    final ratio = (target == null || target <= 0)
        ? null
        : (balance / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _showDisabled
            ? theme.cardColor
            : (isDark ? theme.cardColor : const Color(0xFFFFF8E7)),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: Colors.white, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet['name']?.toString() ?? 'Kantong',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color),
                    ),
                    Text(
                      wallet['currency']?.toString() ?? 'IDR',
                      style: TextStyle(fontSize: 11, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              if (_isOwner)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, size: 20, color: theme.hintColor),
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showWalletFormDialog(wallet: wallet);
                        break;
                      case 'transfer':
                        _showTransferSheet(from: wallet);
                        break;
                      case 'disable':
                        _confirmDisable(wallet);
                        break;
                      case 'restore':
                        _restore(wallet);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    if (!_showDisabled) ...[
                      const PopupMenuItem(
                          value: 'edit', child: Text('Ubah nama & target')),
                      const PopupMenuItem(
                          value: 'transfer', child: Text('Pindah saldo')),
                      const PopupMenuItem(
                          value: 'disable', child: Text('Nonaktifkan')),
                    ] else
                      const PopupMenuItem(
                          value: 'restore', child: Text('Aktifkan kembali')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text('Saldo saat ini',
              style: TextStyle(fontSize: 11, color: theme.hintColor)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _balanceHidden ? 'Rp ••••••' : _rp(balance),
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color),
            ),
          ),
          if (ratio != null && !_balanceHidden) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('Target kantong',
                      style: TextStyle(fontSize: 11, color: theme.hintColor)),
                ),
                Text(
                  '${(ratio * 100).round()}%  (${_rpShort(target!)})',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor: theme.dividerColor.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
          if (_showDisabled) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _blue,
                  side: const BorderSide(color: _blue),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _restore(wallet),
                icon: const Icon(Icons.restart_alt, size: 17),
                label: const Text('Aktifkan kembali',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ] else if (_isOwner) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showTopUpSheet(wallet),
                      icon: const Icon(Icons.add_circle_outline,
                          size: 16, color: Colors.white),
                      label: const Text('Isi saldo',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.textTheme.bodyLarge?.color,
                        backgroundColor: theme.cardColor,
                        side: BorderSide(color: color.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showTransferSheet(from: wallet),
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Pindah',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _createCard() {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showWalletFormDialog(),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: _amber.withOpacity(0.6),
              width: 1.4,
              strokeAlign: BorderSide.strokeAlignInside),
        ),
        child: Column(
          children: [
            Container(
              height: 46,
              width: 46,
              decoration:
              const BoxDecoration(color: _amber, shape: BoxShape.circle),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            Text('Buat kantong baru',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color)),
            const SizedBox(height: 4),
            Text(
              'Pisahkan kas operasional, stok, gaji, dan tabungan agar arus kas toko lebih rapi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: theme.hintColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _allocationCard() {
    final theme = Theme.of(context);
    final data = _wallets
        .where((w) => _balanceOf(w) > 0)
        .toList()
      ..sort((a, b) => _balanceOf(b).compareTo(_balanceOf(a)));
    final total = data.fold<double>(0, (s, w) => s + _balanceOf(w));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.donut_small_outlined, size: 18, color: _blue),
              const SizedBox(width: 8),
              Text('Alokasi kas toko',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color)),
            ],
          ),
          const SizedBox(height: 2),
          Text('Komposisi saldo tiap kantong saat ini',
              style: TextStyle(fontSize: 11, color: theme.hintColor)),
          const SizedBox(height: 18),
          if (data.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: Text('Belum ada saldo untuk ditampilkan',
                    style: TextStyle(fontSize: 12, color: theme.hintColor)),
              ),
            )
          else ...[
            SizedBox(
              height: 170,
              child: CustomPaint(
                size: Size.infinite,
                painter: _DonutPainter(
                  values: data.map(_balanceOf).toList(),
                  colors: [
                    for (int i = 0; i < data.length; i++)
                      _palette[i % _palette.length]
                  ],
                  trackColor: theme.dividerColor.withOpacity(0.2),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Total dana',
                          style: TextStyle(fontSize: 11, color: theme.hintColor)),
                      const SizedBox(height: 2),
                      Text(_rpShort(total),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < data.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      height: 9,
                      width: 9,
                      decoration: BoxDecoration(
                          color: _palette[i % _palette.length],
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data[i]['name']?.toString() ?? 'Kantong',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyLarge?.color),
                      ),
                    ),
                    Text(
                      '${(total == 0 ? 0 : _balanceOf(data[i]) / total * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 78,
                      child: Text(_rpShort(_balanceOf(data[i])),
                          textAlign: TextAlign.right,
                          style: TextStyle(fontSize: 11, color: theme.hintColor)),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _historyCard() {
    final theme = Theme.of(context);
    final rows = _transferHistory
        .where((t) => (t['type']?.toString().toLowerCase() ?? '') == 'expense')
        .take(5)
        .toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Riwayat pindah saldo',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 2),
          Text('Mutasi dana internal antar kantong toko',
              style: TextStyle(fontSize: 11, color: theme.hintColor)),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Belum ada mutasi antar kantong.',
                  style: TextStyle(fontSize: 12, color: theme.hintColor)),
            )
          else
            for (final t in rows) _historyRow(t),
        ],
      ),
    );
  }

  Widget _historyRow(Map<String, dynamic> t) {
    final theme = Theme.of(context);
    final raw = (t['description']?.toString() ?? '')
        .replaceFirst(_transferTag, '')
        .trim();
    final parts = raw.split('>');
    final from = parts.isNotEmpty ? parts[0].trim() : 'Kantong';
    final to = parts.length > 1 ? parts[1].trim() : 'Kantong';
    final date = DateTime.tryParse(
        (t['date'] ?? t['created_at'] ?? '').toString());

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? _blue.withOpacity(0.25)
                  : const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.swap_horiz, size: 17, color: _blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(from,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color)),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(Icons.arrow_forward,
                          size: 12, color: Colors.grey),
                    ),
                    Flexible(
                      child: Text(to,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.textTheme.bodyLarge?.color)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  date == null ? '-' : _formatDate(date),
                  style: TextStyle(fontSize: 10, color: theme.hintColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_rp(_toDouble(t['amount'])),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color)),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year} • $hh:$mm';
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color trackColor;

  _DonutPainter({
    required this.values,
    required this.colors,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (s, v) => s + v);
    if (total <= 0) return;

    final radius = math.min(size.width, size.height) / 2 - 10;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke // Diperbaiki dari PaintingStyle.style ?? PaintingStyle.stroke
      ..strokeWidth = 22;
    canvas.drawCircle(center, radius, track);

    double start = -math.pi / 2;
    const gap = 0.035;
    for (int i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 2 * math.pi;
      if (sweep <= gap) {
        start += sweep;
        continue;
      }
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start + gap / 2, sweep - gap, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => true;
}