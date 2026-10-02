import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../../../app/theme.dart';
import '../providers/stats_filter_provider.dart';
import '../providers/stats_providers.dart';
import '../widgets/category_pie_chart.dart';
import '../widgets/cost_profit_overview.dart';
import '../widgets/product_ranking.dart';
import '../widgets/revenue_line_chart.dart';
import '../widgets/stats_filter_bar.dart';
import '../widgets/stats_overview.dart';
import 'orders_screen.dart';

/// 统计页：时间筛选 + 概览 + 每日趋势 + 单品排行 + 区间订单入口
class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  @override
  void initState() {
    super.initState();
    // 日期选择器 / 标签的中文本地化（异步加载，幂等）
    initializeDateFormatting('zh_CN');
  }

  @override
  Widget build(BuildContext context) {
    UiScale.init(context);
    final filter = ref.watch(statsFilterProvider);
    final summary = ref.watch(statsSummaryProvider);
    final daily = ref.watch(statsDailyRevenueProvider);
    final ranking = ref.watch(statsProductSalesProvider);
    final costTotal = ref.watch(statsCostTotalProvider);
    final breakdown = ref.watch(statsCategoryBreakdownProvider);
    final pad = UiScale.scale(12);

    return Scaffold(
      appBar: AppBar(title: const Text('统计')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(statsSummaryProvider);
            ref.invalidate(statsDailyRevenueProvider);
            ref.invalidate(statsProductSalesProvider);
            ref.invalidate(statsOrdersProvider);
            ref.invalidate(statsCostTotalProvider);
            ref.invalidate(statsCategoryBreakdownProvider);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(pad),
            children: [
              const StatsFilterBar(),
              SizedBox(height: pad),
              summary.when(
                loading: () => const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('读取失败：$e'),
                data: (s) => StatsOverview(summary: s),
              ),
              SizedBox(height: pad),
              costTotal.when(
                loading: () => const SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('读取失败：$e'),
                data: (cost) => summary.maybeWhen(
                  data: (s) => CostProfitOverview(
                    revenueCents: s.totalCents,
                    costCents: cost,
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
              SizedBox(height: pad),
              // 按日只有一个数据点，不展示趋势图
              if (filter.mode != StatsRangeMode.day)
                daily.when(
                  loading: () => const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('读取失败：$e'),
                  data: (d) => RevenueLineChart(
                    daily: d,
                    days: filter.range.days,
                    startMs: filter.range.start,
                  ),
                ),
              if (filter.mode != StatsRangeMode.day) SizedBox(height: pad),
              Padding(
                padding: EdgeInsets.only(
                  left: UiScale.scale(4),
                  bottom: UiScale.scale(8),
                ),
                child: Text(
                  '单品销量排行',
                  style: TextStyle(
                    fontSize: UiScale.scale(16),
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ranking.when(
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('读取失败：$e'),
                data: (list) => ProductRanking(sales: list),
              ),
              SizedBox(height: pad),
              breakdown.when(
                loading: () => const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('读取失败：$e'),
                data: (list) => list.isEmpty
                    ? const SizedBox.shrink()
                    : CategoryPieChart(items: list),
              ),
              SizedBox(height: pad),
              _OrdersEntry(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OrdersScreen(),
                    ),
                  );
                },
              ),
              SizedBox(height: pad),
            ],
          ),
        ),
      ),
    );
  }
}

/// 底部「区间订单明细」入口卡片
class _OrdersEntry extends StatelessWidget {
  const _OrdersEntry({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: UiScale.scale(14),
          vertical: UiScale.scale(16),
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(UiScale.scale(14)),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.receipt_long_rounded,
                color: AppColors.selected),
            SizedBox(width: UiScale.scale(12)),
            Expanded(
              child: Text(
                '区间订单明细',
                style: TextStyle(
                  fontSize: UiScale.scale(16),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
