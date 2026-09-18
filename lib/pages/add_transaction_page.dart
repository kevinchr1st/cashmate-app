import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import 'owner/category_page.dart';
import 'owner/wallet_page.dart';

class AddTransactionPage extends StatefulWidget {
  /// Diisi saat mode edit (transaksi tertentu yang sedang diperbaiki).
  final Map<String, dynamic>? initialTransaction;

  /// Pra-pilih tipe transaksi saat membuka form baru: 'income' | 'expense'.
  /// Digunakan tombol aksi cepat (membuka form langsung dengan tipe terpilih).
  final String? initialType;

  const AddTransactionPage({
    super.key,
    this.initialTransaction,
    this.initialType,
  });

  bool get isEditing => initialTransaction != null;

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage> {
  static const _primaryBlue = Color(0xFF1155D9);

  final amountController = TextEditingController();
  final notesController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String selectedType =
      'income'; // 'income' -> Uang Masuk, 'expense' -> Uang Keluar
  DateTime selectedDateTime = DateTime.now();

  bool isLoadingMasterData = true;
  bool isSaving = false;
  bool isOwner = true;

  List<Map<String, dynamic>> wallets = [];
  List<Map<String, dynamic>> categories = [];
  Map<String, dynamic>? selectedWallet;
  Map<String, dynamic>? selectedCategory;

  XFile? receiptImage;
  int? receiptImageSizeBytes;

  // Foto struk yang SUDAH diunggah sebelumnya (khusus mode edit), diambil dari raw['photos']
  String? existingPhotoUrl;
  int? existingPhotoId;
  bool isDeletingExistingPhoto = false;

  List<Map<String, dynamic>> get categoryOptions =>
      categories.where((c) => c['type'] == selectedType).toList();

  bool get isEditing => widget.isEditing;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final raw = widget.initialTransaction!;
      selectedType = raw['type'] == 'expense' ? 'expense' : 'income';
      final amount = raw['amount'];
      if (amount != null) {
        amountController.text = _thousands(amount.toString().split('.').first);
      }
      notesController.text =
          (raw['description'] ?? raw['title'] ?? '').toString();
      final rawDate = raw['date'] ?? raw['created_at'];
      final parsed =
          rawDate != null ? DateTime.tryParse(rawDate.toString()) : null;
      if (parsed != null) selectedDateTime = parsed;

      // Muat foto struk yang sudah pernah diunggah (jika ada) dari response API
      final rawPhotos = raw['photos'];
      if (rawPhotos is List && rawPhotos.isNotEmpty) {
        final firstPhoto = rawPhotos.first;
        if (firstPhoto is Map) {
          final path = firstPhoto['url']?.toString();
          if (path != null && path.isNotEmpty) {
            existingPhotoUrl = _resolvePhotoUrl(path);
            existingPhotoId = int.tryParse(firstPhoto['id'].toString());
          }
        }
      }
    } else if (widget.initialType != null) {
      // Mode baru: hormati pra-pilih tipe dari tombol aksi cepat (Kasir).
      selectedType =
          widget.initialType == 'expense' ? 'expense' : 'income';
    }
    _loadUserRole();
    _loadMasterData();
  }

  @override
  void dispose() {
    amountController.dispose();
    notesController.dispose();
    super.dispose();
  }

  Future<void> _loadUserRole() async {
    final owner = await ApiService.isOwner();
    if (mounted) setState(() => isOwner = owner);
  }

  Future<void> _loadMasterData() async {
    setState(() => isLoadingMasterData = true);
    try {
      final walletData = await ApiService.fetchWallets();
      final categoryData = await ApiService.fetchCategories();

      setState(() {
        wallets = walletData;
        categories = categoryData;

        if (isEditing) {
          final raw = widget.initialTransaction!;
          final walletId = raw['wallet_id']?.toString();
          final categoryId = raw['category_id']?.toString();
          selectedWallet = wallets.firstWhere(
            (w) => w['id'].toString() == walletId,
            orElse: () =>
                wallets.isNotEmpty ? wallets.first : <String, dynamic>{},
          );
          if (selectedWallet!.isEmpty) selectedWallet = null;

          selectedCategory = categoryOptions.firstWhere(
            (c) => c['id'].toString() == categoryId,
            orElse: () => categoryOptions.isNotEmpty
                ? categoryOptions.first
                : <String, dynamic>{},
          );
          if (selectedCategory!.isEmpty) selectedCategory = null;
        } else {
          if (wallets.isNotEmpty) selectedWallet = wallets.first;
          if (categoryOptions.isNotEmpty)
            selectedCategory = categoryOptions.first;
        }
      });
    } catch (e) {
      debugPrint('Error _loadMasterData (AddTransactionPage): $e');
    } finally {
      if (mounted) setState(() => isLoadingMasterData = false);
    }
  }

  double _parseAmount(String text) =>
      double.tryParse(text.replaceAll('.', '').trim()) ?? 0;

  String _thousands(String digits) {
    digits = digits.replaceAll(RegExp(r'[^0-9]'), '');
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  String _formatRupiah(num amount) {
    final str = amount.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return 'Rp ${str.replaceAllMapped(reg, (m) => '${m[1]}.')}';
  }

  void _addQuickAmount(int value) {
    final current = _parseAmount(amountController.text);
    final newAmount = current + value;
    setState(() {
      amountController.text = _thousands(newAmount.toInt().toString());
      amountController.selection =
          TextSelection.collapsed(offset: amountController.text.length);
    });
  }

  IconData _walletIcon(Map<String, dynamic> w) {
    final n = (w['name'] ?? '').toString().toLowerCase();
    if (n.contains('bank') ||
        n.contains('bca') ||
        n.contains('bri') ||
        n.contains('mandiri') ||
        n.contains('bni')) return Icons.account_balance;
    if (n.contains('qris') || n.contains('qr')) return Icons.qr_code_2;
    if (n.contains('petty') || n.contains('kecil')) return Icons.savings;
    return Icons.point_of_sale;
  }

  String _walletBalanceLabel(Map<String, dynamic> w) {
    final n = (w['name'] ?? '').toString().toLowerCase();
    if (n.contains('qris')) return 'Saldo settlement';
    if (n.contains('petty') || n.contains('kecil')) return 'Saldo sisa';
    return 'Saldo saat ini';
  }

  IconData _categoryIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('jual') || n.contains('produk') || n.contains('sales'))
      return Icons.storefront;
    if (n.contains('jasa') || n.contains('layanan') || n.contains('service'))
      return Icons.build;
    if (n.contains('bahan') ||
        n.contains('stok') ||
        n.contains('stock') ||
        n.contains('baku')) {
      return Icons.inventory_2;
    }
    if (n.contains('operasional') ||
        n.contains('toko') ||
        n.contains('transport')) {
      return Icons.local_shipping;
    }
    if (n.contains('gaji') || n.contains('upah') || n.contains('payroll'))
      return Icons.payments;
    return Icons.more_horiz;
  }

  Future<void> _pickReceiptImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (picked == null) {
        // pickImage() balik null tanpa exception biasanya berarti user membatalkan
        // ATAU izin kamera ditolak sistem (sering terjadi diam-diam di HP MIUI/Xiaomi).
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Kamera tidak terbuka. Pastikan izin Kamera untuk aplikasi ini sudah diaktifkan di Pengaturan HP.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final sizeBytes = await picked.length();
      if (sizeBytes > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Ukuran foto melebihi 5MB, coba ambil ulang.')),
          );
        }
        return;
      }

      setState(() {
        receiptImage = picked;
        receiptImageSizeBytes = sizeBytes;
      });
    } catch (e) {
      debugPrint('Error _pickReceiptImage: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal membuka kamera: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _removeReceiptImage() {
    setState(() {
      receiptImage = null;
      receiptImageSizeBytes = null;
    });
  }

  // Backend mengembalikan path relatif (contoh: "/uploads/transactions/1/abc.jpg"),
  // jadi perlu digabung dengan root server (baseUrl tanpa suffix "/api").
  String _resolvePhotoUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final root = AppConstants.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
    return '$root$path';
  }

  Future<void> _removeExistingPhoto() async {
    if (!isEditing || existingPhotoId == null) {
      setState(() {
        existingPhotoUrl = null;
        existingPhotoId = null;
      });
      return;
    }

    final transactionId =
        int.tryParse(widget.initialTransaction!['id'].toString());
    if (transactionId == null) return;

    setState(() => isDeletingExistingPhoto = true);
    final result = await ApiService.deleteTransactionPhoto(
      transactionId: transactionId,
      photoId: existingPhotoId!,
    );

    if (!mounted) return;
    setState(() => isDeletingExistingPhoto = false);

    if (result['success'] == true) {
      setState(() {
        existingPhotoUrl = null;
        existingPhotoId = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(result['message'] ?? 'Gagal menghapus foto struk'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null) return;

    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(selectedDateTime),
    );

    setState(() {
      selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? selectedDateTime.hour,
        time?.minute ?? selectedDateTime.minute,
      );
    });
  }

  static const _monthNames = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember'
  ];

  String get _formattedDateTime {
    final d = selectedDateTime;
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '${d.day.toString().padLeft(2, '0')} ${_monthNames[d.month]} ${d.year}, $hh:$mm WIB';
  }

  bool get _isBackdated {
    final now = DateTime.now();
    return !(selectedDateTime.year == now.year &&
        selectedDateTime.month == now.month &&
        selectedDateTime.day == now.day);
  }

  double get _walletBalance {
    final b = selectedWallet?['balance'];
    if (b == null) return double.infinity;
    return (b as num).toDouble();
  }

  bool get _isInsufficient {
    // Staff tidak diberi info saldo → jangan pernah blokir dengan ini.
    if (!isOwner) return false;
    final amount = _parseAmount(amountController.text);
    return selectedType == 'expense' && amount > _walletBalance;
  }

  bool get _canSave {
    final amount = _parseAmount(amountController.text);
    return amount > 0 &&
        selectedWallet != null &&
        selectedCategory != null &&
        !_isInsufficient &&
        !isSaving;
  }

  // Staff tidak berhak menentukan tanggal/backdate: payload hanya dikirim
  // untuk Owner yang memilih tanggal lampau. Staff selalu memakai waktu
  // server (DateTime.now() saat menyimpan) secara read-only.
  String? get _dateParam {
    if (isOwner && _isBackdated) {
      final d = selectedDateTime;
      return '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';
    }
    return null;
  }

  Future<void> _saveTransaction() async {
    final amount = _parseAmount(amountController.text);
    final walletId = int.tryParse(selectedWallet!['id'].toString());
    final categoryId = int.tryParse(selectedCategory!['id'].toString());
    if (walletId == null || categoryId == null) return;

    setState(() => isSaving = true);

    final String? dateParam = _dateParam;

    try {
      // Menyesuaikan parameter agar persis dengan format body Postman
      final result = isEditing
          ? await ApiService.updateTransaction(
              transactionId:
                  int.parse(widget.initialTransaction!['id'].toString()),
              walletId: walletId,
              categoryId: categoryId,
              amount: amount,
              type: selectedType,
              description: notesController.text.trim().isEmpty
                  ? null
                  : notesController.text.trim(),
              date: dateParam,
            )
          : await ApiService.createTransaction(
              walletId: walletId,
              categoryId: categoryId,
              amount: amount,
              type: selectedType,
              description: notesController.text.trim().isEmpty
                  ? null
                  : notesController.text.trim(),
              date: dateParam,
              photoFile: receiptImage != null ? File(receiptImage!.path) : null,
            );

      if (!mounted) return;

      if (result['success'] == true) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(result['message'] ?? 'Transaksi berhasil disimpan!'),
              backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal menyimpan: ${result['message']}'),
              backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint('Error _saveTransaction: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Terjadi kesalahan koneksi ke server.'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _goToWalletPage() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const WalletPage()));
    if (mounted) await _loadMasterData();
  }

  Future<void> _goToCategoryPage() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const CategoryPage()));
    if (mounted) await _loadMasterData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.cardColor,
        elevation: 0.5,
        iconTheme: IconThemeData(color: theme.textTheme.bodyLarge?.color),
        title: Text(
          isEditing ? 'Edit Transaksi' : 'Catat Transaksi Baru',
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: isLoadingMasterData
          ? const Center(child: CircularProgressIndicator())
          : wallets.isEmpty
              ? _buildEmptyWalletState(theme)
              : SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _buildTypeToggle(theme),
                      const SizedBox(height: 14),
                      _buildAmountCard(theme),
                      const SizedBox(height: 14),
                      _buildWalletCard(theme),
                      const SizedBox(height: 14),
                      _buildCategoryCard(theme),
                      const SizedBox(height: 14),
                      _buildDateTimeCard(theme),
                      const SizedBox(height: 14),
                      _buildNotesCard(theme),
                      const SizedBox(height: 14),
                      _buildReceiptCard(theme),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
      bottomNavigationBar: (isLoadingMasterData || wallets.isEmpty)
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildImpactBar(theme),
                    const SizedBox(height: 10),
                    _buildSaveButton(),
                    const SizedBox(height: 6),
                    Text(
                      'Otomatis tercatat di laporan CashMate.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyWalletState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 48, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(
              'Belum ada Dompet / Kantong Kas',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: theme.textTheme.bodyLarge?.color),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              isOwner
                  ? 'Buat wallet untuk mulai mencatat.'
                  : 'Minta Owner membuat wallet.',
              style: TextStyle(fontSize: 12, color: theme.hintColor),
              textAlign: TextAlign.center,
            ),
            if (isOwner) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _primaryBlue),
                onPressed: _goToWalletPage,
                child: const Text('Buat Wallet',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypeToggle(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Expanded(
              child: _typeButton(
                  'income', 'Uang Masuk', Icons.arrow_upward, theme)),
          Expanded(
              child: _typeButton(
                  'expense', 'Uang Keluar', Icons.arrow_downward, theme)),
        ],
      ),
    );
  }

  Widget _typeButton(
      String type, String label, IconData icon, ThemeData theme) {
    final bool selected = selectedType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedType = type;
          selectedCategory =
              categoryOptions.isNotEmpty ? categoryOptions.first : null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? _primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16, color: selected ? Colors.white : theme.hintColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color:
                    selected ? Colors.white : theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(ThemeData theme) {
    const quickAmounts = [50000, 100000, 250000, 500000, 1000000];
    return _card(theme, [
      _label('Nominal (Rp)', theme, required: true),
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text('Rp ',
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _primaryBlue)),
          ),
          Expanded(
            child: TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [_ThousandsInputFormatter(_thousands)],
              onChanged: (_) => setState(() {}),
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: theme.textTheme.bodyLarge?.color),
              decoration: const InputDecoration(
                hintText: '0',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
      if (_isInsufficient)
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('⚠️ Saldo dompet ini tidak cukup.',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.red,
                  fontWeight: FontWeight.bold)),
        ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: quickAmounts.map((v) {
          final label = v >= 1000000
              ? '+${(v / 1000000).toStringAsFixed(0)}jt'
              : '+${(v / 1000).toStringAsFixed(0)}rb';
          return GestureDetector(
            onTap: () => _addQuickAmount(v),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
              ),
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color)),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  Widget _buildWalletCard(ThemeData theme) {
    return _card(theme, [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _label('Dompet / Kantong Kas', theme, required: true),
          Text('${wallets.length} dompet',
              style: const TextStyle(
                  fontSize: 11,
                  color: _primaryBlue,
                  fontWeight: FontWeight.w600)),
        ],
      ),
      const SizedBox(height: 10),
      ...wallets.map((w) {
        final bool selected =
            selectedWallet != null && selectedWallet!['id'] == w['id'];
        final bool hasBalance =
            w.containsKey('balance') && w['balance'] != null;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () => setState(() => selectedWallet = w),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: selected
                    ? _primaryBlue.withOpacity(0.15)
                    : theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? _primaryBlue
                      : theme.dividerColor.withOpacity(0.15),
                  width: 1.3,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: theme.cardColor,
                    child: Icon(_walletIcon(w), color: _primaryBlue, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((w['name'] ?? '-').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: theme.textTheme.bodyLarge?.color)),
                        const SizedBox(height: 2),
                        Text(
                          isOwner
                              ? (hasBalance
                                  ? '${_walletBalanceLabel(w)}: ${_formatRupiah((w['balance'] as num))}'
                                  : 'Saldo tidak ditampilkan')
                              : 'Saldo tersembunyi untuk Staff',
                          style:
                              TextStyle(fontSize: 11.5, color: theme.hintColor),
                        ),
                      ],
                    ),
                  ),
                  Radio<int>(
                    value: w['id'] as int,
                    groupValue: selectedWallet?['id'] as int?,
                    activeColor: _primaryBlue,
                    onChanged: (_) => setState(() => selectedWallet = w),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    ]);
  }

  Widget _buildCategoryCard(ThemeData theme) {
    return _card(theme, [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _label('Kategori', theme, required: true),
        ],
      ),
      const SizedBox(height: 10),
      if (categoryOptions.isEmpty)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('⚠️ Belum ada kategori.',
                style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            OutlinedButton(
                onPressed: _goToCategoryPage,
                child: const Text('Buat Kategori')),
          ],
        )
      else
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categoryOptions.map((c) {
            final bool selected =
                selectedCategory != null && selectedCategory!['id'] == c['id'];
            return GestureDetector(
              onTap: () => setState(() => selectedCategory = c),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color:
                      selected ? _primaryBlue : theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: selected
                          ? _primaryBlue
                          : theme.dividerColor.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_categoryIcon((c['name'] ?? '').toString()),
                        size: 16,
                        color: selected ? Colors.white : theme.hintColor),
                    const SizedBox(width: 6),
                    Text(
                      (c['name'] ?? '-').toString(),
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : theme.textTheme.bodyLarge?.color),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
    ]);
  }

  Widget _buildDateTimeCard(ThemeData theme) {
    final bool readOnly = !isOwner;
    return _card(theme, [
      _label(readOnly ? 'Tanggal & Waktu (Otomatis)' : 'Tanggal & Waktu',
          theme, required: true),
      const SizedBox(height: 10),
      if (readOnly)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: _primaryBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formattedDateTime,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: theme.textTheme.bodyLarge?.color)),
                    Text(
                      'Diisi otomatis saat transaksi disimpan',
                      style: TextStyle(fontSize: 11, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              Icon(Icons.lock_outline, size: 16, color: theme.hintColor),
            ],
          ),
        )
      else
        GestureDetector(
          onTap: _pickDateTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: _primaryBlue),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(_formattedDateTime,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: theme.textTheme.bodyLarge?.color))),
                Icon(Icons.access_time, size: 18, color: theme.hintColor),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _buildNotesCard(ThemeData theme) {
    return _card(theme, [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _label('Catatan', theme),
          Text('Opsional',
              style: TextStyle(fontSize: 11, color: theme.hintColor)),
        ],
      ),
      const SizedBox(height: 8),
      TextField(
        controller: notesController,
        maxLines: 3,
        style: TextStyle(fontSize: 13, color: theme.textTheme.bodyLarge?.color),
        decoration: InputDecoration(
          hintText: 'Contoh: Penjualan produk, biaya operasional...',
          hintStyle: TextStyle(fontSize: 12, color: theme.hintColor),
          filled: true,
          fillColor: theme.scaffoldBackgroundColor,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: theme.dividerColor.withOpacity(0.15))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: theme.dividerColor.withOpacity(0.15))),
        ),
      ),
    ]);
  }

  Widget _buildReceiptCard(ThemeData theme) {
    return _card(theme, [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Bukti Struk / Nota Fisik',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: theme.textTheme.bodyLarge?.color)),
          Text('Audit Owner',
              style: TextStyle(fontSize: 11, color: theme.hintColor)),
        ],
      ),
      const SizedBox(height: 10),
      if (isEditing)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'Foto baru hanya bisa dilampirkan saat transaksi baru.',
            style: TextStyle(
                fontSize: 10.5,
                color: theme.hintColor,
                fontStyle: FontStyle.italic),
          ),
        ),
      if (receiptImage == null && existingPhotoUrl == null)
        GestureDetector(
          onTap: _pickReceiptImage,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 22),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.cardColor,
                  child: const Icon(Icons.camera_alt_outlined,
                      color: _primaryBlue),
                ),
                const SizedBox(height: 8),
                const Text('Ambil Foto Struk / Nota',
                    style: TextStyle(
                        color: _primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                const SizedBox(height: 2),
                Text('Maksimal 5MB (JPG/PNG)',
                    style: TextStyle(fontSize: 10.5, color: theme.hintColor)),
              ],
            ),
          ),
        )
      else if (receiptImage == null && existingPhotoUrl != null)
        // Foto struk yang sudah pernah diunggah sebelumnya (mode edit)
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onTap: () => _openImageViewer(networkUrl: existingPhotoUrl),
                  child: Image.network(
                    existingPhotoUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      );
                    },
                    errorBuilder: (context, error, stack) => Container(
                      width: 44,
                      height: 44,
                      color: theme.dividerColor.withOpacity(0.1),
                      child: Icon(Icons.broken_image_outlined,
                          size: 20, color: theme.hintColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Foto Struk Tersimpan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyLarge?.color)),
                    const SizedBox(height: 2),
                    const Text('✓ Sudah diunggah sebelumnya',
                        style: TextStyle(fontSize: 11, color: Colors.green)),
                  ],
                ),
              ),
              isDeletingExistingPhoto
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(2.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      onPressed: _removeExistingPhoto,
                    ),
            ],
          ),
        )
      else
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: GestureDetector(
                  onTap: () => _openImageViewer(file: File(receiptImage!.path)),
                  child: Image.file(File(receiptImage!.path),
                      width: 44, height: 44, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(receiptImage!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyLarge?.color)),
                    const SizedBox(height: 2),
                    Text('✓ Terlampir',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.green)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: _removeReceiptImage,
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _buildImpactBar(ThemeData theme) {
    final amount = _parseAmount(amountController.text);
    final bool hasAmount = amount > 0;
    final bool isIncome = selectedType == 'income';
    // Nominal tunggal tanpa tanda +/- ganda; arah kas ditunjukkan chip label.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _primaryBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(isIncome ? Icons.trending_up : Icons.trending_down,
              size: 18,
              color: hasAmount
                  ? (isIncome ? Colors.green : Colors.red)
                  : theme.hintColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dampak ke Saldo',
                    style: TextStyle(fontSize: 11, color: theme.hintColor)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatRupiah(amount),
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: hasAmount
                          ? (isIncome ? Colors.green : Colors.red)
                          : theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color:
                  isIncome ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isIncome ? 'Kas Masuk' : 'Kas Keluar',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color:
                    isIncome ? Colors.green.shade800 : Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _canSave ? _primaryBlue : Colors.grey.shade400,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        onPressed: _canSave ? _saveTransaction : null,
        child: isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.4))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.save_outlined,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Update Transaksi Kas' : 'Simpan Transaksi Kas',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                ],
              ),
      ),
    );
  }

  void _openImageViewer({String? networkUrl, File? file}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _FullImageViewerPage(imageUrl: networkUrl, imageFile: file),
        fullscreenDialog: true,
      ),
    );
  }

  Widget _card(ThemeData theme, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _label(String text, ThemeData theme, {bool required = false}) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color),
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(text: ' *', style: TextStyle(color: Colors.red)),
        ],
      ),
    );
  }
}

class _ThousandsInputFormatter extends TextInputFormatter {
  final String Function(String digits) formatter;
  _ThousandsInputFormatter(this.formatter);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    final formatted = formatter(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// Halaman full-screen untuk melihat foto struk secara penuh, bisa di-pinch zoom.
// Mendukung dua sumber: foto yang sudah diunggah ke server (imageUrl) atau
// foto lokal yang baru diambil dan belum tersimpan (imageFile).
class _FullImageViewerPage extends StatelessWidget {
  final String? imageUrl;
  final File? imageFile;

  const _FullImageViewerPage({this.imageUrl, this.imageFile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Text('Bukti Struk / Nota',
            style: TextStyle(color: Colors.white, fontSize: 14)),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 5,
          child: imageFile != null
              ? Image.file(imageFile!, fit: BoxFit.contain)
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const CircularProgressIndicator(color: Colors.white);
                  },
                  errorBuilder: (context, error, stack) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          color: Colors.white54, size: 48),
                      SizedBox(height: 8),
                      Text('Gagal memuat foto',
                          style: TextStyle(color: Colors.white54)),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
