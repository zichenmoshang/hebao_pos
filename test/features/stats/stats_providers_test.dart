import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/database/app_database.dart' hide Product;
import 'package:hebao_pos/core/database/app_database_provider.dart';
import 'package:hebao_pos/core/repositories/cost_repository.dart';
import 'package:hebao_pos/core/repositories/order_repository.dart';
import 'package:hebao_pos/features/stats/providers/stats_providers.dart';
import 'package:hebao_pos/shared/models/order_line.dart';
import 'package:hebao_pos/shared/models/product.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late OrderRepository orderRepo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    orderRepo = OrderRepository(db);
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: const Value(1),
            name: '肉锅贴',
            priceCents: 100,
            createdAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> checkout(int quantity) => orderRepo.checkout([
        OrderLine(
          product: const Product(id: 1, name: '肉锅贴', priceCents: 100),
          quantity: quantity,
        ),
      ]);

  group('区间统计 providers', () {
    test('statsSummaryProvider 聚合营业额与订单数', () async {
      await checkout(2);
      await checkout(1);

      final summary = await container.read(statsSummaryProvider.future);
      expect(summary.totalCents, 300);
      expect(summary.orderCount, 2);
    });

    test('statsDailyRevenueProvider 返回当天营业额', () async {
      await checkout(2);

      final revenue =
          await container.read(statsDailyRevenueProvider.future);
      expect(revenue, {0: 200});
    });

    test('statsProductSalesProvider 聚合单品销量', () async {
      await checkout(2);
      await checkout(3);

      final sales = await container.read(statsProductSalesProvider.future);
      expect(sales.single.productId, 1);
      expect(sales.single.quantity, 5);
      expect(sales.single.amountCents, 500);
    });

    test('statsDailyProductQuantityProvider 返回指定商品当天销量', () async {
      await checkout(2);

      final quantities = await container
          .read(statsDailyProductQuantityProvider(1).future);
      expect(quantities, {0: 2});
    });

    test('orderItemsProvider 返回订单明细', () async {
      final orderId = await checkout(2);

      final items = await container.read(orderItemsProvider(orderId).future);
      expect(items.single.name, '肉锅贴');
      expect(items.single.quantity, 2);
      expect(items.single.amountCents, 200);
    });

    test('statsCostTotalProvider 与 statsCategoryBreakdownProvider 聚合成本',
        () async {
      final categoryId = await db.into(db.costCategories).insert(
            CostCategoriesCompanion.insert(name: '猪肉'),
          );
      await CostRepository(db).addRecord(
        categoryId: categoryId,
        amountCents: 5000,
        occurredOn: DateTime.now(),
      );

      expect(await container.read(statsCostTotalProvider.future), 5000);

      final breakdown =
          await container.read(statsCategoryBreakdownProvider.future);
      expect(breakdown.single.name, '猪肉');
      expect(breakdown.single.amountCents, 5000);
    });
  });

  group('pagedStatsOrdersProvider', () {
    test('首页取满 statsPageSize，loadMore 接续，removeById 移除记录', () async {
      for (var i = 0; i < statsPageSize + 5; i++) {
        await checkout(1);
      }

      final sub = container.listen(pagedStatsOrdersProvider, (_, _) {});
      addTearDown(sub.close);

      final firstPage =
          await container.read(pagedStatsOrdersProvider.future);
      expect(firstPage.items, hasLength(statsPageSize));
      expect(firstPage.hasMore, isTrue);

      await container.read(pagedStatsOrdersProvider.notifier).loadMore();

      final loaded = container.read(pagedStatsOrdersProvider).value!;
      expect(loaded.items, hasLength(statsPageSize + 5));
      expect(loaded.hasMore, isFalse);
      // 倒序：最新在前，无重复
      expect(loaded.items.map((e) => e.id).toSet(),
          hasLength(statsPageSize + 5));
      expect(loaded.items.first.id, greaterThan(loaded.items.last.id));

      final removedId = loaded.items.first.id;
      container.read(pagedStatsOrdersProvider.notifier).removeById(removedId);
      final afterRemove = container.read(pagedStatsOrdersProvider).value!;
      expect(afterRemove.items, hasLength(statsPageSize + 4));
      expect(
        afterRemove.items.any((e) => e.id == removedId),
        isFalse,
      );
    });

    test('订单不足一页时 hasMore 为 false，loadMore 为空操作', () async {
      await checkout(1);
      await checkout(1);

      final sub = container.listen(pagedStatsOrdersProvider, (_, _) {});
      addTearDown(sub.close);

      final firstPage =
          await container.read(pagedStatsOrdersProvider.future);
      expect(firstPage.items, hasLength(2));
      expect(firstPage.hasMore, isFalse);

      await container.read(pagedStatsOrdersProvider.notifier).loadMore();
      expect(container.read(pagedStatsOrdersProvider).value!.items,
          hasLength(2));
    });
  });
}
