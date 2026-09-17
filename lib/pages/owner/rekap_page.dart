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
  double get _totalIncome => _monthlyData.fold(0.0, (s, m) => s + _d(m['income']));
  double get _totalExpense => _monthlyData.fold(0.0, (s, m) => s + _d(m['expense']));
  double get _netCashflow => _totalIncome - _totalExpense;

  static const _monthLabels = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  static const _monthFull = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
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
              child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CASHMATE UMKM', style: TextStyle(fontSize: 10, color: theme.hintColor, fontWeight: FontWeight.bold)),
                Text('Rekap Bulanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
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
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            else if (_monthlyData.isEmpty)
              _buildEmptyState(theme)
            else ...[
              // ---- Chart ----
              _buildChartCard(theme),
              const SizedBox(height: 20),

              // ---- Table ----
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
            onPressed: selectedYear >= DateTime.now().year ? null : () => _changeYear(1),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(ThemeData theme) {
    return Row(
      children: [
        Expanded(child: _summaryCard('Pemasukan', _totalIncome, _green, Icons.arrow_downward, theme)),
        const SizedBox(width: 10),
        Expanded(child: _summaryCard('Pengeluaran', _totalExpense, _red, Icons.arrow_upward, theme)),
        const SizedBox(width: 10),
        Expanded(child: _summaryCard('Net', _netCashflow, _netCashflow >= 0 ? _green : _red, Icons.trending_up, theme)),
      ],
    );
  }

  Widget _summaryCard(String label, double value, Color color, IconData icon, ThemeData theme) {
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
              Flexible(child: Text(label, style: TextStyle(fontSize: 11, color: theme.hintColor))),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _formatCompact(value),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(ThemeData theme) {
    // Cari max value untuk Y axis
    double maxY = 0;
    for (final m in _monthlyData) {
      final inc = _d(m['income']);
      final exp = _d(m['expense']);
      if (inc > maxY) maxY = inc;
      if (exp > maxY) maxY = exp;
    }
    maxY = maxY == 0 ? 100000 : maxY * 1.2;

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
          Text('Grafik Pemasukan & Pengeluaran',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 8),
          // Legend
          Row(
            children: [
              _legendDot(_green, 'Pemasukan'),
              const SizedBox(width: 16),
              _legendDot(_red, 'Pengeluaran'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = rodIndex == 0 ? 'Pemasukan' : 'Pengeluaran';
                      return BarTooltipItem(
                        '$label\n${_formatRupiah(rod.toY)}',
                        const TextStyle(color: Colors.white, fontSize: 11),
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
                        if (idx < 0 || idx >= 12) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(_monthLabels[idx], style: TextStyle(fontSize: 9, color: theme.hintColor)),
                        );
                      },
                      reservedSize: 24,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (value, meta) {
                        return Text(_formatCompact(value), style: TextStyle(fontSize: 9, color: theme.hintColor));
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: theme.dividerColor.withOpacity(0.15),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(12, (i) {
                  final inc = i < _monthlyData.length ? _d(_monthlyData[i]['income']) : 0.0;
                  final exp = i < _monthlyData.length ? _d(_monthlyData[i]['expense']) : 0.0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(toY: inc, color: _green, width: 6, borderRadius: BorderRadius.circular(3)),
                      BarChartRodData(toY: exp, color: _red, width: 6, borderRadius: BorderRadius.circular(3)),
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
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildMonthlyTable(ThemeData theme) {
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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 12),
          // Header
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Expanded(flex: 2, child: Text('Bulan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Pemasukan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _green), textAlign: TextAlign.right)),
                Expanded(flex: 2, child: Text('Pengeluaran', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _red), textAlign: TextAlign.right)),
                const Expanded(flex: 2, child: Text('Net', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
              ],
            ),
          ),
          Divider(height: 1, color: theme.dividerColor.withOpacity(0.2)),
          ...List.generate(12, (i) {
            final inc = i < _monthlyData.length ? _d(_monthlyData[i]['income']) : 0.0;
            final exp = i < _monthlyData.length ? _d(_monthlyData[i]['expense']) : 0.0;
            final net = i < _monthlyData.length ? _d(_monthlyData[i]['net_cashflow']) : 0.0;
            final hasData = inc > 0 || exp > 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      _monthFull[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: hasData ? theme.textTheme.bodyLarge?.color : theme.hintColor,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatCompact(inc),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, color: hasData ? _green : theme.hintColor),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatCompact(exp),
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 12, color: hasData ? _red : theme.hintColor),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatCompact(net),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: hasData ? FontWeight.bold : FontWeight.normal,
                        color: hasData ? (net >= 0 ? _green : _red) : theme.hintColor,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          Divider(height: 16, color: theme.dividerColor.withOpacity(0.2)),
          // Total row
          Row(
            children: [
              const Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text(_formatCompact(_totalIncome), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _green))),
              Expanded(flex: 2, child: Text(_formatCompact(_totalExpense), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _red))),
              Expanded(flex: 2, child: Text(_formatCompact(_netCashflow), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _netCashflow >= 0 ? _green : _red))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            Icon(Icons.bar_chart_outlined, size: 48, color: theme.hintColor),
            const SizedBox(height: 12),
            Text('Belum ada data untuk tahun $selectedYear',
                style: TextStyle(color: theme.hintColor, fontSize: 13)),
            const SizedBox(height: 6),
            Text('Coba pilih tahun lain atau catat transaksi terlebih dahulu.',
                style: TextStyle(fontSize: 11, color: theme.hintColor)),
          ],
        ),
      ),
    );
  }
}