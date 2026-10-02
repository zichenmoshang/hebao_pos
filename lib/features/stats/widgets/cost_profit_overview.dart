import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';

/// 成本毛利概览行：采购额 / 毛利 / 毛利率
class CostProfitOverview extends StatelessWidget {
  const CostProfitOverview({
    super.key,
    required this.revenueCents,
    required this.costCents,
  });

  final int revenueCents;
  final int costCents;

  @override
  Widget build(BuildContext context) {
    final profit = revenueCents - costCents;
    // 营业额为 0 时毛利率无意义
    final marginLabel = revenueCents == 0
        ? '—'
        : '${(profit / revenueCents * 100).toStringAsFixed(1)}%';

    return Row(
      children: [
        Expanded(
          child: _Card(
            label: '采购额',
            value: formatCents(costCents),
          ),
        ),
        SizedBox(width: UiScale.scale(8)),
        Expanded(
          child: _Card(
            label: '毛利',
            value: formatCents(profit),
            valueColor: profit < 0 ? AppColors.danger : AppColors.textPrimary,
          ),
        ),
        SizedBox(width: UiScale.scale(8)),
        Expanded(
          child: _Card(
            label: '毛利率',
            value: marginLabel,
            valueColor: profit < 0 ? AppColors.danger : AppColors.selected,
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: UiScale.scale(10),
        vertical: UiScale.scale(14),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(UiScale.scale(14)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: UiScale.scale(13),
              color: AppColors.textMuted,
            ),
          ),
          SizedBox(height: UiScale.scale(6)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: UiScale.scale(20),
                fontWeight: FontWeight.w800,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
