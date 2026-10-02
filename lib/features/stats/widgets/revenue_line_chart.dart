import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';

/// 区间内每日营业额折线图。
/// [daily] 为「距起点第 n 天 -> 金额(分)」，[days] 为区间天数。
class RevenueLineChart extends StatelessWidget {
  const RevenueLineChart({
    super.key,
    required this.daily,
    required this.days,
    required this.startMs,
  });

  final Map<int, int> daily;
  final int days;
  final int startMs;

  /// 候选纵轴刻度间隔（分）：保证取整、好读
  static const _steps = [
    50, 100, 200, 500, 1000, 2000, 5000,
    10000, 20000, 50000, 100000, 200000, 500000,
  ];

  @override
  Widget build(BuildContext context) {
    final values = [
      for (var i = 0; i < days; i++) (daily[i] ?? 0).toDouble(),
    ];
    final maxCents = values.fold<double>(0, (a, b) => a > b ? a : b);

    if (maxCents == 0) {
      return _frame(
        context,
        SizedBox(
          height: UiScale.scale(120),
          child: Center(
            child: Text(
              '该区间暂无数据',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: UiScale.scale(14),
              ),
            ),
          ),
        ),
      );
    }

    // 选一个「好看」的刻度间隔：使总格数在 4~5 格以内
    final rough = maxCents * 1.15;
    final step = _steps.firstWhere(
      (s) => rough / s <= 5,
      orElse: () => _steps.last,
    ).toDouble();
    final maxY = (maxCents / step).ceil() * step;

    return _frame(
      context,
      SizedBox(
        height: UiScale.scale(200),
        child: LineChart(
          LineChartData(
            minX: 0,
            maxX: (days - 1).toDouble(),
            minY: 0,
            maxY: maxY,
            clipData: FlClipData.all(),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: step,
              getDrawingHorizontalLine: (v) => const FlLine(
                color: AppColors.border,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: step,
                  reservedSize: UiScale.scale(38),
                  getTitlesWidget: (value, meta) => Text(
                    _yuanLabel(value.toInt()),
                    style: TextStyle(
                      fontSize: UiScale.scale(10),
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  interval: (days / 5).clamp(1, days).toDouble(),
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= days) {
                      return const SizedBox.shrink();
                    }
                    final date = DateTime.fromMillisecondsSinceEpoch(
                        startMs + i * 86400000);
                    return Padding(
                      padding: EdgeInsets.only(top: UiScale.scale(6)),
                      child: Text(
                        DateFormat('M/d').format(date),
                        style: TextStyle(
                          fontSize: UiScale.scale(10),
                          color: AppColors.textMuted,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                // 数据稀疏且含尖峰，不做贝塞尔平滑，避免曲线下冲/上冲失真
                isCurved: false,
                spots: [
                  for (var i = 0; i < days; i++)
                    FlSpot(i.toDouble(), values[i]),
                ],
                color: AppColors.selected,
                barWidth: 2.5,
                dotData: FlDotData(show: days <= 12),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.selected.withValues(alpha: 0.08),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 统一卡片外壳：标题 + 内容
  Widget _frame(BuildContext context, Widget child) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        UiScale.scale(14),
        UiScale.scale(14),
        UiScale.scale(14),
        UiScale.scale(10),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(UiScale.scale(14)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '每日营业额',
            style: TextStyle(
              fontSize: UiScale.scale(15),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: UiScale.scale(12)),
          child,
        ],
      ),
    );
  }

  /// 纵轴刻度：分 → 紧凑「元」数字（不带 ¥，减少拥挤）
  String _yuanLabel(int cents) {
    final yuan = cents / 100;
    if (cents % 100 == 0) return yuan.toInt().toString();
    return yuan.toStringAsFixed(1);
  }
}
