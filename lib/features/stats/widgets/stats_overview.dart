import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/repositories/order_repository.dart';
import '../../../core/utils/money.dart';

/// 概览指标卡片：营业额 / 订单数 / 客单价
class StatsOverview extends StatelessWidget {
  const StatsOverview({super.key, required this.summary});

  final OrderSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Card(
            label: '营业额',
            value: formatCents(summary.totalCents),
            accent: true,
          ),
        ),
        SizedBox(width: UiScale.scale(8)),
        Expanded(
          child: _Card(
            label: '订单数',
            value: '${summary.orderCount}',
          ),
        ),
        SizedBox(width: UiScale.scale(8)),
        Expanded(
          child: _Card(
            label: '客单价',
            value: formatCents(summary.avgCents),
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
    this.accent = false,
  });

  final String label;
  final String value;
  final bool accent;

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
                color: accent ? AppColors.selected : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
