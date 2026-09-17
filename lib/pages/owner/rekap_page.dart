import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';

/// Halaman Rekap Bulanan Owner — menggunakan GET /reports/monthly?year=YYYY
/// sebagai sumber data tunggal. Menampilkan chart pemasukan + pengeluaran
/// dan tabel net cashflow per bulan.
class RekapPage extends StatefulWidget {
  final int userId;

  const RekapPage({super.key, required this.userId});

  @override
  State<RekapPage> createState() => _RekapPageState();
}

class _RekapPageState extends State<RekapPage> {
  static const _blue = Color(0xFF1155D9);
  static const _green = Color(0xFF12B76A);
  static const _red = Color(0xFFE5484D);
  static const _amber = Color(0xFFF5A524);

  bool isLoading = false;
  int selectedYear = DateTime.now().year;

  // Data dari /reports/monthly — 12 entri: { month, income, expense, net_cashflow }
  List<Map<String, dynamic>> _monthlyData = [];

  // Ringkasan
  double get _totalIncome =>
      _monthlyData.fold(0.0, (s, m) => s + _d(m['income']));
  double get _totalExpense =>
      _monthlyData.fold(0.0, (s, m) => s + _d(m['expense']));
  double get _netCashflow => _totalIncome - _totalExpense;

  static const _monthLabels = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Ags',
    'Sep',
    'Okt',
    'Nov',
    'Des'
  ];

  static const _monthFull = [
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

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => isLoading = true);
    final data = await ApiService.getMonthlyReport(year: selectedYear);
    if (!mounted) return;
    setState(() {
      _monthlyData = data;
      isLoading = false;
    });
  }

  void _changeYear(int delta) {
    setState(() => selectedYear += delta);
    _loadReport();
  }

  String _formatRupiah(num amount) {
    String str = amount.round().abs().toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    String result = str.replaceAllMapped(reg, (Match m) => '${m[1]}.');
    return amount < 0 ? '-Rp $result' : 'Rp $result';
  }

  String _formatCompact(double amount) {
    final abs = amount.abs();
    String result;
    if (abs >= 1000000000) {
      result = '${(abs / 1000000000).toStringAsFixed(1)}M';
    } else if (abs >= 1000000) {
      result = '${(abs / 1000000).toStringAsFixed(1)}jt';
    } else if (abs >= 1000) {
      result = '${(abs / 1000).toStringAsFixed(0)}rb';
    } else {
      result = abs.toStringAsFixed(0);
    }
    return amount < 0 ? '-$result' : result;
  }

  double _d(dynamic v) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  /// Peta data per bulan (1..12). Jika field `month` tidak ada/tidak valid,
  /// tetap urutkan sesuai posisi list (asumsi API mengembalikan Jan–Des)
  /// agar chart & tabel tidak tampil kosong padahal datanya ada.
  Map<int, Map<String, dynamic>> _monthMap() {
    final result = <int, Map<String, dynamic>>{};
    var hasValidMonth = false;
    for (final m in _monthlyData) {
      final monthNum = _d(m['month']).toInt();
      if (monthNum >= 1 && monthNum <= 12) {
        result[monthNum] = m;
        hasValidMonth = true;
      }
    }
    if (!hasValidMonth) {
      for (var i = 0; i < _monthlyData.length && i < 12; i++) {
        result[i + 1] = _monthlyData[i];
      }
    }
    return result;
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
                color: _blue,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CASHMATE UMKM',
                    style: TextStyle(
                        fontSize: 10,
                        color: theme.hintColor,
                        fontWeight: FontWeight.bold)),
                Text('Rekap Bulanan',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color)),
              ],
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadReport,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ---- Year picker ----
            _buildYearPicker(theme),
            const SizedBox(height: 16),

            // ---- Summary cards ----
            _buildSummaryCards(theme),
            const SizedBox(height: 20),

            if (isLoading)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator()))
            else ...[
              // ---- Chart (selalu tampil 12 bulan, data kosong = 0) ----
              _buildChartCard(theme),
              const SizedBox(height: 20),

              // ---- Tabel ----
              _buildMonthlyTable(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildYearPicker(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeYear(-1),
          ),
          Text(
            'Tahun $selectedYear',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: selectedYear >= DateTime.now().year
                ? null
                : () => _changeYear(1),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    return Row(
      children: [
        Expanded(
            child: _summaryCard('Pemasukan', _totalIncome, _green,
                Icons.arrow_downward, theme)),
        const SizedBox(width: 10),
        Expanded(
            child: _summaryCard(
                'Pengeluaran', _totalExpense, _red, Icons.arrow_upward, theme)),
        const SizedBox(width: 10),
        Expanded(
            child: _summaryCard('Net', _netCashflow,
                _netCashflow >= 0 ? _green : _red, Icons.trending_up, theme)),
      ],
    );
  }

  Widget _summaryCard(
      String label, double value, Color color, IconData icon, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(
                  child: Text(label,
                      style: TextStyle(fontSize: 11, color: theme.hintColor))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatCompact(value),
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(ThemeData theme) {
    // Map data per bulan (1..12) agar posisi bar akurat
    final monthMap = _monthMap();

    // Cari max value untuk Y axis
    double maxY = 0;
    for (int i = 1; i <= 12; i++) {
      final row = monthMap[i];
      final inc = _d(row?['income']);
      final exp = _d(row?['expense']);
      if (inc > maxY) maxY = inc;
      if (exp > maxY) maxY = exp;
    }
    maxY = maxY == 0 ? 100000 : maxY * 1.25;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Grafik Pemasukan & Pengeluaran',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.textTheme.bodyLarge?.color)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_blue, _amber],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Tahun $selectedYear',
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Legend
          Row(
            children: [
              _legendDot(_blue, 'Pemasukan'),
              const SizedBox(width: 16),
              _legendDot(_amber, 'Pengeluaran'),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                // Skala sumbu Y dinamis mengikuti nilai maksimum data,
                // bukan statis — jadi bar 10jt tidak "tenggelam" ke bawah.
                minY: 0,
                maxY: maxY,
                groupsSpace: 10,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1E293B),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = rodIndex == 0 ? 'Pemasukan' : 'Pengeluaran';
                      return BarTooltipItem(
                        '$label\n${_formatRupiah(rod.toY)}',
                        const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= 12)
                          return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_monthLabels[idx],
                              style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: theme.hintColor)),
                        );
                      },
                      reservedSize: 26,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(_formatCompact(value),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                  fontSize: 9, color: theme.hintColor)),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.dividerColor.withOpacity(0.12),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(12, (i) {
                  final row = monthMap[i + 1];
                  final inc = _d(row?['income']);
                  final exp = _d(row?['expense']);
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: inc,
                        color: _blue,
                        width: 9,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                      BarChartRodData(
                        toY: exp,
                        color: _amber,
                        width: 9,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
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
            width: 10,
            height: 10,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildMonthlyTable(ThemeData theme) {
    final monthMap = _monthMap();

    // Warna latar header & zebra — mengikuti mode terang/gelap.
    final Color headerBg = theme.colorScheme.surfaceContainerHighest;
    final Color zebraBg = theme.dividerColor.withValues(alpha: 0.06);
    final Color rowLine = theme.dividerColor.withValues(alpha: 0.15);
    final Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final Color faintColor = theme.hintColor;

    const TextAlign right = TextAlign.right;

    // Kolom responsif: Bulan lebih lebar, kolom nominal rata kanan.
    const monthCol = FlexColumnWidth(5);
    const moneyCol = FlexColumnWidth(3);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rincian Per Bulan',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
          const SizedBox(height: 12),
          Table(
            // Lebar kolom proporsional (flex) agar tidak overflow di HP kecil.
            columnWidths: const {
              0: monthCol,
              1: moneyCol,
              2: moneyCol,
              3: moneyCol,
            },
            // Border tipis antar baris + pemisah kolom yang halus.
            border: TableBorder(
              horizontalInside: BorderSide(color: rowLine, width: 0.7),
              right: BorderSide(color: rowLine, width: 0.7),
            ),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              // ---- Header ----
              TableRow(
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(8)),
                ),
                children: [
                  _tableText('Bulan',
                      left: true, bold: true, color: textColor, header: true),
                  _tableText('Pemasukan',
                      right: right, bold: true, color: _green, header: true),
                  _tableText('Pengeluaran',
                      right: right, bold: true, color: _red, header: true),
                  _tableText('Net',
                      right: right, bold: true, color: textColor, header: true),
                ],
              ),
              // ---- Baris per bulan (zebra) ----
              for (int i = 0; i < 12; i++)
                TableRow(
                  decoration: BoxDecoration(
                    // Selang-seling putih / abu sangat muda agar mudah dibaca.
                    color: i.isOdd ? zebraBg : null,
                  ),
                  children: [
                    _tableText(
                      _monthFull[i],
                      left: true,
                      color:
                          hasDataOf(monthMap, i + 1) ? textColor : faintColor,
                    ),
                    _tableText(
                      _formatCompact(amountOf(monthMap, i + 1, 'income')),
                      right: right,
                      color: hasDataOf(monthMap, i + 1) ? _green : faintColor,
                    ),
                    _tableText(
                      _formatCompact(amountOf(monthMap, i + 1, 'expense')),
                      right: right,
                      color: hasDataOf(monthMap, i + 1) ? _red : faintColor,
                    ),
                    _tableText(
                      _formatCompact(amountOf(monthMap, i + 1, 'net_cashflow')),
                      right: right,
                      bold: hasDataOf(monthMap, i + 1),
                      color: netColorOf(monthMap, i + 1, faintColor),
                    ),
                  ],
                ),
              // ---- Total ----
              TableRow(
                decoration: BoxDecoration(
                  color: headerBg,
                  borderRadius:
                      const BorderRadius.vertical(bottom: Radius.circular(8)),
                ),
                children: [
                  _tableText('TOTAL',
                      left: true, bold: true, color: textColor, isTotal: true),
                  _tableText(_formatCompact(_totalIncome),
                      right: right, bold: true, color: _green, isTotal: true),
                  _tableText(_formatCompact(_totalExpense),
                      right: right, bold: true, color: _red, isTotal: true),
                  _tableText(
                    _formatCompact(_netCashflow),
                    right: right,
                    bold: true,
                    color: _netCashflow >= 0 ? _green : _red,
                    isTotal: true,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Helper teks sel tabel: rata kiri untuk Bulan, rata kanan untuk nominal.
  Widget _tableText(
    String text, {
    TextAlign? right,
    bool left = false,
    bool bold = false,
    bool header = false,
    bool isTotal = false,
    required Color color,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: header ? 10 : 9,
        horizontal: 4,
      ),
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.ellipsis,
        textAlign: right ?? (left ? TextAlign.left : TextAlign.right),
        style: TextStyle(
          fontSize: isTotal ? 12.5 : 12,
          fontWeight: bold
              ? FontWeight.w700
              : (header ? FontWeight.w700 : FontWeight.w500),
          color: color,
        ),
      ),
    );
  }

  double amountOf(Map<int, Map<String, dynamic>> map, int month, String key) {
    final row = map[month];
    return row == null ? 0.0 : _d(row[key]);
  }

  bool hasDataOf(Map<int, Map<String, dynamic>> map, int month) {
    final row = map[month];
    return row != null && (_d(row['income']) > 0 || _d(row['expense']) > 0);
  }

  Color netColorOf(
    Map<int, Map<String, dynamic>> map,
    int month,
    Color emptyColor,
  ) {
    final row = map[month];
    if (row == null) return emptyColor;
    return _d(row['net_cashflow']) >= 0 ? _green : _red;
  }
}
