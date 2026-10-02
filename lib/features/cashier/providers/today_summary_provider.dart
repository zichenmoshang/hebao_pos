import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/order_repository.dart';
import '../../../core/utils/date_range.dart';

/// 当日流水（营业额 + 订单数）：从数据库实时聚合。
/// 结账落库后通过 invalidate 刷新，重启不丢。
final todaySummaryProvider = FutureProvider<OrderSummary>((ref) async {
  final repo = ref.watch(orderRepositoryProvider);
  return repo.summary(dayRange(DateTime.now()));
});
