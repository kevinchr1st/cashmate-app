import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/constants.dart'; // Naik dua level ke folder utils/

/// Ringkasan satu kategori (bisa kategori income maupun expense) hasil agregasi
/// dari /transactions pada periode yang sedang dipilih.
class _CategoryBreakdown {
  final String name;
  final double amount;
  double percentage; // dihitung ulang setelah semua kategori terkumpul
  _CategoryBreakdown(this.name, this.amount, [this.percentage = 0]);
}

class RekapPage extends StatefulWidget {
  final int userId;

  const RekapPage({super.key, required this.userId});

  @override
  State<RekapPage> createState() => _RekapPageState();
}

class _RekapPageState extends State<RekapPage> {
  bool isLoading = false;
  bool isExporting = false;

  // 'Harian' | 'Mingguan' | 'Bulanan' | 'Tahunan'
  String selectedPeriod = 'Bulanan';
  DateTime selectedDate = DateTime.now();

  String userRole = 'OWNER';
  String businessName = 'CashMate UMKM';

  // ---------- Ringkasan periode terpilih (dari GET /transactions) ----------
  double totalIncome = 0;
  double totalExpense = 0;
  int incomeCount = 0;
  int expenseCount = 0;
  double get netProfit => totalIncome - totalExpense;

  // Pertumbuhan dibanding bulan sebelumnya (hanya berlaku untuk tab Bulanan,
  // karena baseline pembandingnya diambil dari /reports/monthly).
  bool hasGrowth = false;
  double growthPercentage = 0;

  // ---------- Data untuk grafik tren ----------
  // Dihitung dari GET /transactions per bulan (bukan /reports/monthly), karena
  // Postman hanya memastikan properti 'net_cashflow' yang pasti ada pada
  // /reports/monthly -- nama field pemasukan/pengeluaran per bulan tidak
  // didokumentasikan, sehingga rawan tidak cocok dengan skema backend dan
  // membuat grafik tampak kosong/datar. /transactions sudah pasti punya
  // 'amount' dan 'type', jadi jauh lebih bisa diandalkan untuk agregasi ini.
  // Setiap entri: {'month': int, 'income': double, 'expense': double}.
  List<Map<String, dynamic>> _trendMonths = [];

  // ---------- Rekap kategori usaha (agregasi client-side dari /transactions) ----------
  List<_CategoryBreakdown> _categoryBreakdown = [];
  Map<int, String> _categoryNameById = {};

  final List<Color> _chartColors = [
    Colors.orange.shade600,
    Colors.blue,
    Colors.green.shade600,
    Colors.purple,
    Colors.red,
  ];

  final GlobalKey _cashFlowChartKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ---------- Helper token & header (sama seperti ApiService) ----------
  Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  String _formatRupiah(num amount) {
    String str = amount.round().toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String result = str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return 'Rp $result';
  }

  String _formatPercent(double value) {
    final sign = value >= 0 ? '+' : '-';
    return '$sign${value.abs().toStringAsFixed(1).replaceAll('.', ',')}%';
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _getMonthName(int month) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return months[month - 1];
  }

  String _getMonthAbbr(int month) {
    const abbr = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return abbr[month - 1];
  }

  /// Rentang tanggal (inklusif) untuk periode yang sedang aktif.
  ({DateTime from, DateTime to}) _rangeForPeriod() {
    switch (selectedPeriod) {
      case 'Harian':
        return (from: selectedDate, to: selectedDate);
      case 'Mingguan':
        return (from: selectedDate.subtract(const Duration(days: 6)), to: selectedDate);
      case 'Tahunan':
        return (from: DateTime(selectedDate.year, 1, 1), to: DateTime(selectedDate.year, 12, 31));
      case 'Bulanan':
      default:
        final lastDay = DateTime(selectedDate.year, selectedDate.month + 1, 0);
        return (from: DateTime(selectedDate.year, selectedDate.month, 1), to: lastDay);
    }
  }

  String _periodLabel() {
    switch (selectedPeriod) {
      case 'Harian':
        return '${selectedDate.day} ${_getMonthAbbr(selectedDate.month)} ${selectedDate.year}';
      case 'Mingguan':
        final from = selectedDate.subtract(const Duration(days: 6));
        return '${from.day} - ${selectedDate.day} ${_getMonthAbbr(selectedDate.month)}';
      case 'Tahunan':
        return '${selectedDate.year}';
      case 'Bulanan':
      default:
        return '${_getMonthAbbr(selectedDate.month)} ${selectedDate.year}';
    }
  }

  String _periodPhrase() {
    switch (selectedPeriod) {
      case 'Harian':
        return 'hari ini';
      case 'Mingguan':
        return 'minggu ini';
      case 'Tahunan':
        return 'tahun ini';
      case 'Bulanan':
      default:
        return 'bulan ini';
    }
  }

  // ---------- Ambil semua data yang dibutuhkan halaman rekap ----------
  Future<void> _loadAll() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      userRole = prefs.getString('user_role') ?? 'OWNER';

      await Future.wait([
        _loadTrend(),
        _loadCategories(),
      ]);
      await _loadPeriodTransactions();
    } catch (e) {
      debugPrint('Error loading rekap: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _refresh() async {
    await _loadAll();
  }

  // Grafik tren menampilkan sampai 5 bulan terakhir (dalam tahun yang sama)
  // hingga bulan yang sedang dipilih. Untuk tiap bulan itu, panggil
  // GET /transactions?from_date=&to_date=&per_page= lalu jumlahkan
  // amount berdasarkan type -- ini persis skema yang dites di Postman
  // ("03/04 ... Transaction History"), jadi hasilnya selalu bisa dipercaya.
  Future<void> _loadTrend() async {
    final endMonth = selectedDate.month;
    final startMonth = (endMonth - 4) < 1 ? 1 : endMonth - 4;
    final months = [for (int m = startMonth; m <= endMonth; m++) m];

    final results = await Future.wait(months.map((m) => _fetchMonthTotals(selectedDate.year, m)));

    if (!mounted) return;
    _trendMonths = [
      for (int i = 0; i < months.length; i++)
        {
          'month': months[i],
          'income': results[i]['income'] ?? 0.0,
          'expense': results[i]['expense'] ?? 0.0,
        }
    ];
  }

  Future<Map<String, double>> _fetchMonthTotals(int year, int month) async {
    double income = 0;
    double expense = 0;
    try {
      final headers = await _getAuthHeaders();
      final from = DateTime(year, month, 1);
      final to = DateTime(year, month + 1, 0);
      final queryParams = {
        'from_date': _ymd(from),
        'to_date': _ymd(to),
        'page': '1',
        'per_page': '200',
      };
      final uri = Uri.parse('${AppConstants.baseUrl}/transactions').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> data = body['data'] ?? [];
        for (final tx in data) {
          final amount = _parseDouble(tx['amount']);
          final type = (tx['type'] ?? '').toString().toLowerCase();
          if (type == 'income') {
            income += amount;
          } else if (type == 'expense') {
            expense += amount;
          }
        }
      } else {
        debugPrint('Gagal ambil transaksi $year-$month: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching month totals ($year-$month): $e');
    }
    return {'income': income, 'expense': expense};
  }

  // GET /categories?status=active -> untuk memetakan category_id -> nama kategori.
  Future<void> _loadCategories() async {
    try {
      final headers = await _getAuthHeaders();
      final url = '${AppConstants.baseUrl}/categories?status=active';
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> data = body['data'] ?? [];
        _categoryNameById = {
          for (final c in data)
            (c['id'] as num).toInt(): (c['name'] ?? 'Lainnya').toString()
        };
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  // GET /transactions?from_date=&to_date=&page=&per_page= -> sumber utama angka
  // pemasukan/pengeluaran dan rekap kategori untuk periode yang dipilih.
  Future<void> _loadPeriodTransactions() async {
    final range = _rangeForPeriod();
    List<Map<String, dynamic>> transactions = [];

    try {
      final headers = await _getAuthHeaders();
      final queryParams = {
        'from_date': _ymd(range.from),
        'to_date': _ymd(range.to),
        'page': '1',
        'per_page': '200',
      };
      final uri = Uri.parse('${AppConstants.baseUrl}/transactions').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final List<dynamic> data = body['data'] ?? [];
        transactions = data.map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching transactions: $e');
    }

    double income = 0;
    double expense = 0;
    int incCount = 0;
    int expCount = 0;
    final Map<String, double> categoryTotals = {};

    for (final tx in transactions) {
      final amount = _parseDouble(tx['amount']);
      final type = (tx['type'] ?? '').toString().toLowerCase();
      final categoryData = tx['category'];
      final categoryId = (tx['category_id'] as num?)?.toInt();
      final categoryName = (categoryData is Map ? categoryData['name'] : null)?.toString() ??
          _categoryNameById[categoryId] ??
          'Lainnya';

      if (type == 'income') {
        income += amount;
        incCount++;
      } else if (type == 'expense') {
        expense += amount;
        expCount++;
      }
      categoryTotals[categoryName] = (categoryTotals[categoryName] ?? 0) + amount;
    }

    // Susun rekap kategori: urutkan dari yang terbesar, ambil 5 teratas,
    // persentase dihitung relatif terhadap total kategori yang ditampilkan
    // (sama seperti "Total Perputaran Kas" pada desain).
    final sortedEntries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = sortedEntries.take(5).toList();
    final topTotal = topEntries.fold<double>(0, (sum, e) => sum + e.value);
    final breakdown = topEntries
        .map((e) => _CategoryBreakdown(e.key, e.value, topTotal > 0 ? (e.value / topTotal) * 100 : 0))
        .toList();

    // Pertumbuhan vs bulan sebelumnya, hanya untuk tab Bulanan, memakai
    // _trendMonths (hasil agregasi /transactions) sebagai baseline -- bulan
    // sebelumnya selalu ada di dalam _trendMonths selama bulan yang dipilih
    // bukan Januari (lihat _loadTrend: rentangnya selalu mencakup bulan-1).
    bool growthAvailable = false;
    double growthPct = 0;
    if (selectedPeriod == 'Bulanan' && selectedDate.month > 1) {
      final prevEntry = _trendMonths.where((e) => e['month'] == selectedDate.month - 1).toList();
      if (prevEntry.isNotEmpty) {
        final prevNet = (prevEntry.first['income'] as double) - (prevEntry.first['expense'] as double);
        if (prevNet != 0) {
          growthAvailable = true;
          growthPct = ((income - expense) - prevNet) / prevNet.abs() * 100;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      totalIncome = income;
      totalExpense = expense;
      incomeCount = incCount;
      expenseCount = expCount;
      _categoryBreakdown = breakdown;
      hasGrowth = growthAvailable;
      growthPercentage = growthPct;
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode:
      selectedPeriod == 'Tahunan' ? DatePickerMode.year : DatePickerMode.day,
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      await _loadAll();
    }
  }

  void _onPeriodTap(String period) async {
    if (period == selectedPeriod) return;
    setState(() => selectedPeriod = period);
    await _loadPeriodTransactions();
  }

  // ---------- Analisis kesehatan kas ----------
  ({String status, Color color, String message}) _healthAnalysis() {
    final ratio = totalIncome > 0 ? (totalExpense / totalIncome) : (totalExpense > 0 ? 1.0 : 0.0);
    final ratioPct = (ratio * 100).toStringAsFixed(1).replaceAll('.', ',');
    final posisi = netProfit >= 0 ? 'surplus' : 'defisit';

    if (ratio <= 0.4) {
      return (
      status: 'Sangat Sehat',
      color: Colors.teal,
      message: 'Arus kas Anda berada pada posisi $posisi positif. Rasio operasional terhadap omset aman di $ratioPct%.',
      );
    } else if (ratio <= 0.7) {
      return (
      status: 'Sehat',
      color: Colors.blue,
      message: 'Arus kas Anda berada pada posisi $posisi. Rasio operasional terhadap omset di $ratioPct%, masih dalam batas wajar.',
      );
    }
    return (
    status: 'Perlu Perhatian',
    color: Colors.orange.shade700,
    message: 'Rasio operasional terhadap omset cukup tinggi, yaitu $ratioPct%. Pertimbangkan untuk meninjau ulang pengeluaran ${_periodPhrase()}.',
    );
  }

  // ---------- PDF Export ----------
  Future<Uint8List?> _captureChartAsImage(GlobalKey key, {double pixelRatio = 3.0}) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundaryContext = key.currentContext;
      if (boundaryContext == null) return null;
      final renderObject = boundaryContext.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) return null;
      final ui.Image image = await renderObject.toImage(pixelRatio: pixelRatio);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint('Gagal menangkap gambar chart: $e');
      return null;
    }
  }

  Future<void> _downloadReport() async {
    setState(() => isExporting = true);
    try {
      final pdf = pw.Document();
      final pdfPrimary = PdfColors.blue800;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(24),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('CASHMATE UMKM',
                              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: pdfPrimary)),
                          pw.Text('Laporan Rekap Keuangan',
                              style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(6)),
                        child: pw.Text(_periodLabel(),
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: pdfPrimary)),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 12),
                  pw.Divider(thickness: 1.5, color: pdfPrimary),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildPdfCard('Total Masuk', _formatRupiah(totalIncome), PdfColors.teal700),
                      pw.SizedBox(width: 8),
                      _buildPdfCard('Total Keluar', _formatRupiah(totalExpense), PdfColors.red700),
                      pw.SizedBox(width: 8),
                      _buildPdfCard('Keuntungan Bersih', _formatRupiah(netProfit), pdfPrimary),
                    ],
                  ),
                  pw.SizedBox(height: 16),
                  if (_categoryBreakdown.isNotEmpty) ...[
                    pw.Text('Rekap Kategori Usaha',
                        style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: pdfPrimary)),
                    pw.SizedBox(height: 6),
                    ..._categoryBreakdown.map((c) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(c.name, style: const pw.TextStyle(fontSize: 10)),
                          pw.Text(_formatRupiah(c.amount), style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    )),
                  ],
                  pw.Spacer(),
                ],
              ),
            );
          },
        ),
      );

      Directory? outputDir;
      if (Platform.isAndroid) {
        outputDir = Directory('/storage/emulated/0/Download');
        if (!await outputDir.exists()) {
          outputDir = await getExternalStorageDirectory();
        }
      } else {
        outputDir = await getApplicationDocumentsDirectory();
      }

      final fileName = 'Laporan_Rekap_${selectedDate.year}_${selectedDate.month.toString().padLeft(2, '0')}.pdf';
      final file = File('${outputDir!.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF Laporan tersimpan di: $fileName'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error generating PDF: $e');
    } finally {
      if (mounted) setState(() => isExporting = false);
    }
  }

  pw.Widget _buildPdfCard(String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true, // Memastikan latar belakang menembus ke bawah navigation bar
      body: SafeArea(
        bottom: false, // Mencegah pemotongan area bawah agar menyatu dengan navigasi
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110), // Padding bawah ditambah agar item terakhir tidak tertutup nav bar
            children: [
              _buildHeader(),
              const SizedBox(height: 14),
              _buildAccessRow(),
              const SizedBox(height: 14),
              _buildNetProfitCard(),
              const SizedBox(height: 16),
              _buildPeriodTabs(),
              const SizedBox(height: 16),
              _buildTrendChartCard(),
              const SizedBox(height: 16),
              _buildCategoryCard(),
              const SizedBox(height: 16),
              _buildHealthCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF1D5FE8).withOpacity(0.1),
          child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF1D5FE8), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(businessName, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const Text('Rekap Keuangan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: isExporting ? null : _downloadReport,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1D5FE8),
            side: const BorderSide(color: Color(0xFF1D5FE8)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          icon: isExporting
              ? const SizedBox(
              width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download, size: 16),
          label: const Text('Unduh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Belum ada notifikasi baru.')),
            );
          },
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade800.withOpacity(0.1)),
            ),
            child: const Icon(Icons.notifications_none_rounded, size: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildAccessRow() {
    final isOwner = userRole.toUpperCase() == 'OWNER';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(radius: 3, backgroundColor: Colors.amber.shade700),
              const SizedBox(width: 6),
              Text('Akses ${isOwner ? 'Owner' : 'Staff'}',
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade900)),
            ],
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: () => _selectDate(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade800.withOpacity(0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_outlined, size: 13, color: Colors.blue),
                const SizedBox(width: 6),
                Text(_periodLabel(),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const Icon(Icons.keyboard_arrow_down, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNetProfitCard() {
    final surplus = netProfit >= 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2C6BEF), Color(0xFF123A9E)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: const Color(0xFF123A9E).withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('KEUNTUNGAN BERSIH (NET PROFIT)',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.4)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(surplus ? Icons.check_circle : Icons.warning_amber_rounded,
                        size: 12, color: surplus ? Colors.greenAccent.shade100 : Colors.orangeAccent.shade100),
                    const SizedBox(width: 4),
                    Text(surplus ? 'Surplus' : 'Defisit',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          isLoading
              ? const SizedBox(
              height: 30,
              width: 30,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(_formatRupiah(netProfit),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          if (hasGrowth) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(growthPercentage >= 0 ? Icons.trending_up : Icons.trending_down,
                      size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text('${_formatPercent(growthPercentage)} dibanding bulan lalu',
                      style: const TextStyle(fontSize: 10, color: Colors.white)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMiniStat('Pemasukan', totalIncome, incomeCount, 'Transaksi Masuk', Icons.arrow_downward)),
              const SizedBox(width: 10),
              Expanded(child: _buildMiniStat('Pengeluaran', totalExpense, expenseCount, 'Transaksi Kas Keluar', Icons.arrow_upward)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String title, double amount, int count, String countLabel, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: 6),
              Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 6),
          Text(_formatRupiah(amount),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text('$count $countLabel', style: const TextStyle(fontSize: 9, color: Colors.white60)),
        ],
      ),
    );
  }

  Widget _buildPeriodTabs() {
    const periods = ['Harian', 'Mingguan', 'Bulanan', 'Tahunan'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade800.withOpacity(0.08)),
      ),
      child: Row(
        children: periods.map((p) {
          final active = p == selectedPeriod;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onPeriodTap(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? const Color(0xFF2C6BEF).withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(
                  p,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active ? const Color(0xFF2C6BEF) : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrendChartCard() {
    final months = _trendMonths.map((e) => e['month'] as int).toList();

    List<FlSpot> inSpots = [];
    List<FlSpot> outSpots = [];
    double maxVal = 1;
    bool hasAnyData = false;

    for (int i = 0; i < _trendMonths.length; i++) {
      final inc = _trendMonths[i]['income'] as double;
      final exp = _trendMonths[i]['expense'] as double;
      inSpots.add(FlSpot(i.toDouble(), inc));
      outSpots.add(FlSpot(i.toDouble(), exp));
      if (inc > 0 || exp > 0) hasAnyData = true;
      if (inc > maxVal) maxVal = inc;
      if (exp > maxVal) maxVal = exp;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Grafik Arus Keuangan',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('Tren Pemasukan vs Pengeluaran ${_trendMonths.length} Bulan Terakhir',
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.grey.shade800.withOpacity(0.06), borderRadius: BorderRadius.circular(8)),
                child: Text('${selectedDate.year}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const CircleAvatar(radius: 4, backgroundColor: Colors.blue),
              const SizedBox(width: 4),
              const Text('Pemasukan', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 10),
              CircleAvatar(radius: 4, backgroundColor: Colors.orange.shade600),
              const SizedBox(width: 4),
              const Text('Pengeluaran', style: TextStyle(fontSize: 10)),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: (netProfit >= 0 ? Colors.teal : Colors.orange).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Text(netProfit >= 0 ? 'Optimal' : 'Perlu Ditinjau',
                    style: TextStyle(
                        fontSize: 9,
                        color: netProfit >= 0 ? Colors.teal : Colors.orange.shade700,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const SizedBox(height: 130, child: Center(child: CircularProgressIndicator()))
          else if (!hasAnyData)
            const SizedBox(
              height: 130,
              child: Center(
                child: Text('Belum ada transaksi pada rentang bulan ini.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            )
          else
            RepaintBoundary(
              key: _cashFlowChartKey,
              child: SizedBox(
                height: 130,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY: maxVal * 1.2,
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx < 0 || idx >= months.length) return const Text('');
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(_getMonthAbbr(months[idx]),
                                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots.map((s) {
                          return LineTooltipItem(_formatRupiah(s.y), const TextStyle(color: Colors.white, fontSize: 10));
                        }).toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: inSpots,
                        isCurved: true,
                        color: Colors.blue,
                        barWidth: 3,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: true, color: Colors.blue.withOpacity(0.12)),
                      ),
                      LineChartBarData(
                        spots: outSpots,
                        isCurved: true,
                        color: Colors.orange.shade600,
                        barWidth: 2,
                        dotData: const FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard() {
    final total = _categoryBreakdown.fold<double>(0, (sum, c) => sum + c.amount);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rekap Kategori Usaha',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    Text('Total Perputaran Kas: ${_formatRupiah(total)}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
              TextButton(
                onPressed: _categoryBreakdown.isEmpty ? null : _showCategoryDetailSheet,
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                child: const Text('Lihat Rinci', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_categoryBreakdown.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text('Belum ada transaksi pada periode ini.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            )
          else
            ..._categoryBreakdown.take(3).toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final c = entry.value;
              return _buildCategoryItem(c, _chartColors[idx % _chartColors.length]);
            }),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(_CategoryBreakdown c, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(radius: 4, backgroundColor: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(c.name,
                    style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              Text(_formatRupiah(c.amount), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: Colors.grey.shade800.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text('${c.percentage.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 9, color: Colors.grey)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: (c.percentage / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade800.withOpacity(0.1),
            color: color,
            minHeight: 3,
          ),
        ],
      ),
    );
  }

  void _showCategoryDetailSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Rincian Kategori Usaha', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._categoryBreakdown.asMap().entries.map((entry) {
                final idx = entry.key;
                final c = entry.value;
                return _buildCategoryItem(c, _chartColors[idx % _chartColors.length]);
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHealthCard() {
    final health = _healthAnalysis();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF2C6BEF).withOpacity(0.1),
                child: const Icon(Icons.verified_user_outlined, size: 14, color: Color(0xFF2C6BEF)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Analisis Kesehatan Kas UMKM',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: health.color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(health.status,
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: health.color)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(health.message, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 12, color: Colors.grey),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('Sisihkan 10% ke Kantong Pajak & Tabungan',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Sisihkan ${_formatRupiah(netProfit * 0.1)} ke Kantong Pajak & Tabungan.')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C6BEF),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Alokasi', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}