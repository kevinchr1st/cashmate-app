import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../utils/app_theme.dart';
import '../../../utils/formatters.dart';
import '../../../widgets/app_card.dart';

/// Kartu grafik keuangan Owner: menampilkan tren pemasukan vs pengeluaran
/// untuk **12 bulan penuh (Januari–Desember)** dari GET /reports/monthly.
class OwnerFinanceChartCard extends StatelessWidget {
  /// Data mentah laporan bulanan: `{ month, income/expense, net_cashflow }`.
  final List<Map<String, dynamic>> report;
  final int year;

  const OwnerFinanceChartCard({
    super.key,
    required this.report,
    required this.year,
  });

  static double _toDouble(dynamic v) =>
      v == null ? 0 : (num.tryParse(v.toString())?.toDouble() ?? 0);

  @override
  Widget build(BuildContext context) {
    // Peta data per bulan agar posisi 1..12 selalu akurat meski API
    // hanya mengirim bulan yang punya transaksi. Jika field `month`
    // tidak ada/tidak valid, pakai urutan list (Jan–Des).
    final Map<int, Map<String, dynamic>> byMonth = {};
    var hasValidMonth = false;
    for (final row in report) {
      final int month = _toDouble(row['month']).toInt();
      if (month >= 1 && month <= 12) {
        byMonth[month] = row;
        hasValidMonth = true;
      }
    }
    if (!hasValidMonth) {
      for (int i = 0; i < report.length && i < 12; i++) {
        byMonth[i + 1] = report[i];
      }
    }

    final List<double> income = List.generate(12, (i) {
      final row = byMonth[i + 1];
      return _toDouble(row?['income'] ?? row?['total_income']);
    });
    final List<double> expense = List.generate(12, (i) {
      final row = byMonth[i + 1];
      return _toDouble(row?['expense'] ?? row?['total_expense']);
    });

    final double maxValue = [
      ...income,
      ...expense,
    ].fold<double>(0, (m, v) => v > m ? v : m);
    final double maxY = maxValue > 0 ? maxValue * 1.22 : 100000;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tren keuangan',
                  style: AppTextStyles.heading.copyWith(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: AppRadius.rSm,
                ),
                child: Text(
                  '$year',
                  style: AppTextStyles.label.copyWith(color: AppColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _LegendDot(color: AppColors.primary, label: 'Pemasukan'),
              const SizedBox(width: AppSpacing.lg),
              _LegendDot(color: AppColors.accent, label: 'Pengeluaran'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: 11,
                minY: 0,
                maxY: maxY,
                clipData: const FlClipData.all(),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xFF1D2939),
                    tooltipRoundedRadius: 10,
                    getTooltipItems: (spots) => spots.map((spot) {
                      final int month = spot.x.toInt().clamp(0, 11);
                      final String label =
                          spot.barIndex == 0 ? 'Pemasukan' : 'Pengeluaran';
                      return LineTooltipItem(
                        '${AppDate.monthShort[month]} · $label\n${Rupiah.format(spot.y)}',
                        const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.border(context),
                    strokeWidth: 1,
                    dashArray: const [4, 5],
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      interval: maxY / 4,
                      getTitlesWidget: (value, meta) {
                        if (value <= 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            Rupiah.compact(value),
                            textAlign: TextAlign.right,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textHint, fontSize: 9.5),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final int i = value.toInt();
                        if (i < 0 || i > 11) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            AppDate.monthShort[i],
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHint,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  _line(income, AppColors.primary, filled: true),
                  _line(expense, AppColors.accent, filled: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _line(
    List<double> values,
    Color color, {
    required bool filled,
  }) {
    return LineChartBarData(
      spots: [
        for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
      ],
      isCurved: true,
      curveSmoothness: 0.28,
      preventCurveOverShooting: true,
      color: color,
      barWidth: 2.6,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: filled,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
