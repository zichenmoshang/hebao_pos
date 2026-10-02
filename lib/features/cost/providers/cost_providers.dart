import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/cost_repository.dart';
import 'cost_filter_provider.dart';

/// 启用类目（记录表单选择用）
final activeCostCategoriesProvider =
    FutureProvider<List<CostCategory>>((ref) async {
  return ref.watch(costRepositoryProvider).activeCategories();
});

/// 全部类目（含已软删，类目管理页用）
final allCostCategoriesProvider =
    FutureProvider<List<CostCategory>>((ref) async {
  return ref.watch(costRepositoryProvider).allCategories();
});

/// 当前区间采购总额（分）
final costTotalProvider = FutureProvider<int>((ref) async {
  final range = ref.watch(costFilterProvider).range;
  return ref.watch(costRepositoryProvider).totalInRange(range);
});

/// 当前区间采购流水（按发生日期倒序）
final costRecordsProvider =
    FutureProvider<List<CostRecord>>((ref) async {
  final range = ref.watch(costFilterProvider).range;
  return ref.watch(costRepositoryProvider).recordsInRange(range);
});
