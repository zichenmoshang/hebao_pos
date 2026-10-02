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

const costPageSize = 20;

/// 区间采购流水分页状态：已累加记录 + 是否还有下一页 + 是否加载中
class CostPagedState {
  const CostPagedState({
    this.items = const [],
    this.hasMore = true,
    this.loadingMore = false,
  });

  final List<CostRecord> items;
  final bool hasMore;
  final bool loadingMore;
}

/// 区间采购流水游标分页（按发生日期、id 倒序）。
/// 直接 watch 筛选 provider：区间变化时自动重建首页，无需 family
class CostRecordsNotifier extends AsyncNotifier<CostPagedState> {
  @override
  Future<CostPagedState> build() async {
    final range = ref.watch(costFilterProvider).range;
    final page = await ref
        .watch(costRepositoryProvider)
        .pagedRecordsInRange(range, limit: costPageSize);
    return CostPagedState(
      items: page,
      hasMore: page.length == costPageSize,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        current.items.isEmpty) {
      return;
    }

    final range = ref.read(costFilterProvider).range;
    final cursor = current.items.last;
    state = AsyncData(CostPagedState(
        items: current.items, hasMore: true, loadingMore: true));

    final page = await ref.read(costRepositoryProvider).pagedRecordsInRange(
          range,
          limit: costPageSize,
          cursorOccurredOn: cursor.occurredOnMs,
          cursorId: cursor.id,
        );
    state = AsyncData(CostPagedState(
      items: [...current.items, ...page],
      hasMore: page.length == costPageSize,
      loadingMore: false,
    ));
  }
}

final pagedCostRecordsProvider =
    AsyncNotifierProvider<CostRecordsNotifier, CostPagedState>(
  CostRecordsNotifier.new,
);
