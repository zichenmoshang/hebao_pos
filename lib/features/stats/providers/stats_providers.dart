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

/// 区间订单列表（按时间倒序）
final statsOrdersProvider =
    FutureProvider<List<OrderRecord>>((ref) async {
  final range = ref.watch(statsFilterProvider).range;
  return ref.watch(orderRepositoryProvider).ordersInRange(range);
});

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
