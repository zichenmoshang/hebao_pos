import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../app/theme.dart';
import '../../../core/repositories/cost_repository.dart';
import '../../../core/utils/money.dart';

/// 采购类目分布：环形占比图 + 各类目金额 / 占比列表
class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({super.key, required this.items});

  final List<CategoryCost> items;

  // 环形图分段配色
  static const _palette = [
    Color(0xFF0E7C86),
    Color(0xFFE8A13C),
    Color(0xFF5B8DEF),
    Color(0xFF8E6FD1),
    Color(0xFF58A96A),
    Color(0xFFE06A8E),
    Color(0xFF6FB7C2),
    Color(0xFFB88A4E),
  ];

  @override
  Widget build(BuildContext context) {
    final total = items.fold<int>(0, (sum, e) => sum + e.amountCents);

    return Container(
      padding: EdgeInsets.all(UiScale.scale(14)),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(UiScale.scale(14)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '采购类目分布',
                  style: TextStyle(
                    fontSize: UiScale.scale(16),
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '仅供参考',
                style: TextStyle(
                  fontSize: UiScale.scale(12),
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          SizedBox(height: UiScale.scale(12)),
          Row(
            children: [
              SizedBox(
                width: UiScale.scale(150),
                height: UiScale.scale(150),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: UiScale.scale(46),
                        sections: [
                          for (var i = 0; i < items.length; i++)
                            PieChartSectionData(
                              value: items[i].amountCents.toDouble(),
                              color: _palette[i % _palette.length],
                              showTitle: false,
                              radius: UiScale.scale(16),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '采购总额',
                          style: TextStyle(
                            fontSize: UiScale.scale(11),
                            color: AppColors.textMuted,
                          ),
                        ),
                        SizedBox(height: UiScale.scale(2)),
                        Text(
                          formatCents(total),
                          style: TextStyle(
                            fontSize: UiScale.scale(15),
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: UiScale.scale(14)),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: UiScale.scale(3),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: UiScale.scale(10),
                              height: UiScale.scale(10),
                              decoration: BoxDecoration(
                                color: _palette[i % _palette.length],
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            SizedBox(width: UiScale.scale(6)),
                            Expanded(
                              child: Text(
                                items[i].name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: UiScale.scale(13),
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              total == 0
                                  ? '0%'
                                  : '${(items[i].amountCents / total * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: UiScale.scale(13),
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: UiScale.scale(10)),
          const Divider(height: 1),
          for (final item in items)
            Padding(
              padding: EdgeInsets.symmetric(vertical: UiScale.scale(6)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: UiScale.scale(14),
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    formatCents(item.amountCents),
                    style: TextStyle(
                      fontSize: UiScale.scale(14),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
