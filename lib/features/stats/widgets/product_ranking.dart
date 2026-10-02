import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/repositories/order_repository.dart';
import '../../../core/utils/money.dart';
import '../providers/stats_filter_provider.dart';
import '../providers/stats_providers.dart';

/// 单品销量排行：点击某行展开该商品区间内每日销量
class ProductRanking extends ConsumerWidget {
  const ProductRanking({super.key, required this.sales});

  final List<ProductSales> sales;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sales.isEmpty) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: UiScale.scale(28)),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(UiScale.scale(14)),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          '该区间暂无销量',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: UiScale.scale(14),
          ),
        ),
      );
    }

    final totalAmount = sales.fold<int>(0, (a, s) => a + s.amountCents);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(UiScale.scale(14)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < sales.length; i++)
            _RankTile(
              rank: i + 1,
              sales: sales[i],
              share: totalAmount == 0
                  ? 0
                  : sales[i].amountCents / totalAmount,
            ),
        ],
      ),
    );
  }
}

class _RankTile extends ConsumerStatefulWidget {
  const _RankTile({
    required this.rank,
    required this.sales,
    required this.share,
  });

  final int rank;
  final ProductSales sales;
  final double share;

  @override
  ConsumerState<_RankTile> createState() => _RankTileState();
}

class _RankTileState extends ConsumerState<_RankTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: UiScale.scale(14),
              vertical: UiScale.scale(14),
            ),
            child: Row(
              children: [
                Container(
                  width: UiScale.scale(26),
                  height: UiScale.scale(26),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.rank <= 3
                        ? AppColors.selected.withValues(alpha: 0.12)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(UiScale.scale(8)),
                  ),
                  child: Text(
                    '${widget.rank}',
                    style: TextStyle(
                      fontSize: UiScale.scale(14),
                      fontWeight: FontWeight.w800,
                      color: widget.rank <= 3
                          ? AppColors.selected
                          : AppColors.textMuted,
                    ),
                  ),
                ),
                SizedBox(width: UiScale.scale(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.sales.name,
                        style: TextStyle(
                          fontSize: UiScale.scale(16),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: UiScale.scale(2)),
                      Text(
                        '销量 ${widget.sales.quantity}  ·  '
                        '${formatCents(widget.sales.amountCents)}  ·  '
                        '占比 ${(widget.share * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: UiScale.scale(12),
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: const Icon(Icons.expand_more_rounded,
                      color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
        if (_expanded) _DailyDetail(productId: widget.sales.productId),
      ],
    );
  }
}

/// 展开区：该商品区间内每日销量
class _DailyDetail extends ConsumerWidget {
  const _DailyDetail({required this.productId});

  final int productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async =
        ref.watch(statsDailyProductQuantityProvider(productId));
    final filter = ref.watch(statsFilterProvider);
    final days = filter.range.days;
    final startMs = filter.range.start;

    return Container(
      margin: EdgeInsets.fromLTRB(
        UiScale.scale(14),
        0,
        UiScale.scale(14),
        UiScale.scale(12),
      ),
      padding: EdgeInsets.all(UiScale.scale(12)),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(UiScale.scale(10)),
      ),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('读取失败：$e'),
        data: (daily) {
          final entries = <Widget>[];
          for (var i = 0; i < days; i++) {
            final qty = daily[i] ?? 0;
            if (qty == 0) continue;
            final date = DateTime.fromMillisecondsSinceEpoch(
                startMs + i * 86400000);
            entries.add(
              Padding(
                padding: EdgeInsets.symmetric(vertical: UiScale.scale(3)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('M月d日 EEE', 'zh_CN').format(date),
                      style: TextStyle(
                        fontSize: UiScale.scale(13),
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '$qty',
                      style: TextStyle(
                        fontSize: UiScale.scale(13),
                        fontWeight: FontWeight.w700,
                        color: AppColors.selected,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          if (entries.isEmpty) {
            return Text(
              '该区间内无销量',
              style: TextStyle(
                fontSize: UiScale.scale(13),
                color: AppColors.textMuted,
              ),
            );
          }
          return Column(children: entries);
        },
      ),
    );
  }
}
