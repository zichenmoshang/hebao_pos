import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/database/app_database.dart' hide CostCategory;
import 'package:hebao_pos/core/database/app_database_provider.dart';
import 'package:hebao_pos/core/repositories/cost_repository.dart';
import 'package:hebao_pos/features/cost/providers/cost_filter_provider.dart';
import 'package:hebao_pos/features/cost/providers/cost_providers.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late CostRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    repo = CostRepository(db);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> seedCategory(String name, {int sortIndex = 0, int isActive = 1}) {
    return db.into(db.costCategories).insert(
          CostCategoriesCompanion.insert(
            name: name,
            sortIndex: Value(sortIndex),
            isActive: Value(isActive),
          ),
        );
  }

  Future<void> addRecords(int categoryId, int count, {DateTime? on}) async {
    for (var i = 0; i < count; i++) {
      await repo.addRecord(
        categoryId: categoryId,
        amountCents: 100 * (i + 1),
        occurredOn: on ?? DateTime.now(),
      );
    }
  }

  group('类目 providers', () {
    test('activeCostCategoriesProvider 只含启用类目', () async {
      await seedCategory('猪肉', sortIndex: 0);
      await seedCategory('面粉', sortIndex: 1, isActive: 0);

      final categories =
          await container.read(activeCostCategoriesProvider.future);
      expect(categories.map((e) => e.name), ['猪肉']);
    });

    test('allCostCategoriesProvider 含已软删类目', () async {
      await seedCategory('猪肉', sortIndex: 0);
      await seedCategory('面粉', sortIndex: 1, isActive: 0);

      final categories =
          await container.read(allCostCategoriesProvider.future);
      expect(categories, hasLength(2));
    });
  });

  group('区间聚合 providers', () {
    test('costTotalProvider 与 costRecordsProvider 跟随筛选区间变化', () async {
      final categoryId = await seedCategory('猪肉');
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));

      await addRecords(categoryId, 2);
      await repo.addRecord(
        categoryId: categoryId,
        amountCents: 900,
        occurredOn: yesterday,
      );

      // 默认筛选为今天：100 + 200
      expect(await container.read(costTotalProvider.future), 300);
      expect(await container.read(costRecordsProvider.future), hasLength(2));

      // 切换筛选到昨天
      container.read(costFilterProvider.notifier).setDay(yesterday);
      expect(await container.read(costTotalProvider.future), 900);
      expect(await container.read(costRecordsProvider.future), hasLength(1));
    });
  });

  group('pagedCostRecordsProvider', () {
    test('首页取满 costPageSize，loadMore 接续到全部记录', () async {
      final categoryId = await seedCategory('猪肉');
      await addRecords(categoryId, costPageSize + 5);

      final sub = container.listen(pagedCostRecordsProvider, (_, _) {});
      addTearDown(sub.close);

      final firstPage =
          await container.read(pagedCostRecordsProvider.future);
      expect(firstPage.items, hasLength(costPageSize));
      expect(firstPage.hasMore, isTrue);
      expect(firstPage.loadingMore, isFalse);

      await container.read(pagedCostRecordsProvider.notifier).loadMore();

      final state = container.read(pagedCostRecordsProvider).value!;
      expect(state.items, hasLength(costPageSize + 5));
      expect(state.hasMore, isFalse);
      // 无重复无遗漏（按 id 倒序）
      expect(state.items.map((e) => e.id).toSet(),
          hasLength(costPageSize + 5));

      // 无更多时 loadMore 不再变化
      await container.read(pagedCostRecordsProvider.notifier).loadMore();
      expect(container.read(pagedCostRecordsProvider).value!.items,
          hasLength(costPageSize + 5));
    });

    test('记录不足一页时 hasMore 为 false，loadMore 为空操作', () async {
      final categoryId = await seedCategory('猪肉');
      await addRecords(categoryId, 3);

      final sub = container.listen(pagedCostRecordsProvider, (_, _) {});
      addTearDown(sub.close);

      final firstPage =
          await container.read(pagedCostRecordsProvider.future);
      expect(firstPage.items, hasLength(3));
      expect(firstPage.hasMore, isFalse);

      await container.read(pagedCostRecordsProvider.notifier).loadMore();
      expect(container.read(pagedCostRecordsProvider).value!.items,
          hasLength(3));
    });
  });
}
