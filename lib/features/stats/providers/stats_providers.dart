import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/cost_repository.dart';
import '../../../core/repositories/order_repository.dart';
import 'stats_filter_provider.dart';

/// 区间概览：营业额 / 订单数 / 客单价
final statsSummaryProvider = FutureProvider<OrderSummary>((ref) async {
  final range = ref.watch(statsFilterProvider).range;
  return ref.watch(orderRepositoryProvider).summary(range);
});

/// 区间内每日营业额：「距起点第 n 天 -> 金额(分)」
final statsDailyRevenueProvider =
    FutureProvider<Map<int, int>>((ref) async {
  final range = ref.watch(statsFilterProvider).range;
  return ref.watch(orderRepositoryProvider).dailyRevenue(range);
});

/// 区间单品销量聚合，按销售额降序
final statsProductSalesProvider =
    FutureProvider<List<ProductSales>>((ref) async {
  final range = ref.watch(statsFilterProvider).range;
  return ref.watch(orderRepositoryProvider).productSales(range);
});

/// 某商品区间内每日销量：「距起点第 n 天 -> 数量」
final statsDailyProductQuantityProvider =
    FutureProvider.family<Map<int, int>, int>((ref, productId) async {
  final range = ref.watch(statsFilterProvider).range;
  return ref
      .watch(orderRepositoryProvider)
      .dailyProductQuantity(productId, range);
});

/// 分页列表通用状态：已累加的记录 + 是否还有下一页 + 是否正在加载
class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.hasMore = true,
    this.loadingMore = false,
  });

  final List<T> items;
  final bool hasMore;
  final bool loadingMore;

  PagedState<T> copyWith({
    List<T>? items,
    bool? hasMore,
    bool? loadingMore,
  }) {
    return PagedState<T>(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
    );
  }
}

const statsPageSize = 20;

/// 区间订单分页列表（游标 keyset，倒序）。
/// 直接 watch 筛选 provider：区间变化时自动重建首页，无需 family
class StatsOrdersNotifier
    extends AsyncNotifier<PagedState<OrderRecord>> {
  @override
  Future<PagedState<OrderRecord>> build() async {
    final range = ref.watch(statsFilterProvider).range;
    final page = await ref
        .watch(orderRepositoryProvider)
        .pagedOrdersInRange(range, limit: statsPageSize);
    return PagedState(
      items: page,
      hasMore: page.length == statsPageSize,
    );
  }

  /// 滚动到底加载下一页
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        current.items.isEmpty) {
      return;
    }

    final range = ref.read(statsFilterProvider).range;
    final cursor = current.items.last;
    // 先置 loadingMore，列表尾部展示加载指示
    state = AsyncData(current.copyWith(loadingMore: true));

    final page = await ref.read(orderRepositoryProvider).pagedOrdersInRange(
          range,
          limit: statsPageSize,
          cursorCreatedAt: cursor.createdAtMs,
          cursorId: cursor.id,
        );
    state = AsyncData(PagedState(
      items: [...current.items, ...page],
      hasMore: page.length == statsPageSize,
      loadingMore: false,
    ));
  }

  /// 删除订单后从已加载列表移除（后续页由滚动继续拉取）
  void removeById(int id) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(
      items: current.items.where((e) => e.id != id).toList(),
    ));
  }
}

final pagedStatsOrdersProvider = AsyncNotifierProvider<StatsOrdersNotifier,
    PagedState<OrderRecord>>(StatsOrdersNotifier.new);

/// 某订单的明细行
final orderItemsProvider =
    FutureProvider.family<List<ProductSales>, int>((ref, orderId) async {
  return ref.watch(orderRepositoryProvider).itemsOfOrder(orderId);
});

/// 当前区间采购总额（分）
final statsCostTotalProvider = FutureProvider<int>((ref) async {
  final range = ref.watch(statsFilterProvider).range;
  return ref.watch(costRepositoryProvider).totalInRange(range);
});

/// 当前区间采购类目分布（含已软删类目）
final statsCategoryBreakdownProvider =
    FutureProvider<List<CategoryCost>>((ref) async {
  final range = ref.watch(statsFilterProvider).range;
  return ref.watch(costRepositoryProvider).categoryBreakdown(range);
});
