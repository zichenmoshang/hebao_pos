import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/database/app_database.dart' hide Product;
import 'package:hebao_pos/core/repositories/order_repository.dart';
import 'package:hebao_pos/core/utils/date_range.dart';
import 'package:hebao_pos/shared/models/order_line.dart';
import 'package:hebao_pos/shared/models/product.dart';

void main() {
  late AppDatabase db;
  late OrderRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = OrderRepository(db);
  });

  tearDown(() => db.close());

  Future<void> seedProduct({
    required int id,
    required String name,
    required int priceCents,
  }) async {
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: Value(id),
            name: name,
            priceCents: priceCents,
            createdAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
          ),
        );
  }

  group('checkout', () {
    test('写入订单与明细并返回订单 id，总额为各行小计之和', () async {
      await seedProduct(id: 1, name: '肉锅贴', priceCents: 80);
      await seedProduct(id: 3, name: '豆浆', priceCents: 200);

      final orderId = await repo.checkout([
        const OrderLine(product: Product(id: 1, name: '肉锅贴', priceCents: 80), quantity: 3),
        const OrderLine(product: Product(id: 3, name: '豆浆', priceCents: 200), quantity: 1),
      ]);

      expect(orderId, 1);
      final orders = await db.select(db.orders).get();
      expect(orders.single.totalCents, 440);
      final items = await db.select(db.orderItems).get();
      expect(items, hasLength(2));
      expect(items.map((e) => e.productName), ['肉锅贴', '豆浆']);
      expect(items.map((e) => e.lineTotalCents), [240, 200]);
    });

    test('明细外键指向不存在商品时整单回滚', () async {
      await seedProduct(id: 1, name: '肉锅贴', priceCents: 80);

      await expectLater(
        () => repo.checkout([
          const OrderLine(
            product: Product(id: 99, name: '已删除商品', priceCents: 100),
            quantity: 1,
          ),
        ]),
        throwsA(anything),
      );

      final orders = await db.select(db.orders).get();
      final items = await db.select(db.orderItems).get();
      expect(orders, isEmpty);
      expect(items, isEmpty);
    });
  });

  group('itemsOfOrders', () {
    test('一次返回多笔订单明细并带出成交单价快照', () async {
      await seedProduct(id: 1, name: '肉锅贴', priceCents: 80);
      await seedProduct(id: 3, name: '豆浆', priceCents: 200);

      final id1 = await repo.checkout([
        const OrderLine(product: Product(id: 1, name: '肉锅贴', priceCents: 80), quantity: 2),
      ]);
      final id2 = await repo.checkout([
        const OrderLine(product: Product(id: 3, name: '豆浆', priceCents: 200), quantity: 1),
      ]);

      final details = await repo.itemsOfOrders([id1, id2]);
      expect(details, hasLength(2));
      expect(details.map((e) => e.orderId), [id1, id2]);
      expect(details.map((e) => e.unitPriceCents), [80, 200]);
    });

    test('空 id 列表直接返回空', () async {
      expect(await repo.itemsOfOrders(const []), isEmpty);
    });
  });

  group('pagedOrdersInRange', () {
    test('按倒序分页，游标正确接续下一页', () async {
      await seedProduct(id: 1, name: '肉锅贴', priceCents: 100);
      // 连续 3 笔
      for (var i = 0; i < 3; i++) {
        await repo.checkout([
          const OrderLine(
            product: Product(id: 1, name: '肉锅贴', priceCents: 100),
            quantity: 1,
          ),
        ]);
        // 保证 createdAt 不落在同一毫秒，游标可分辨
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }

      final now = DateTime.now();
      final range = DateRange(
        DateTime(now.year, now.month, now.day).millisecondsSinceEpoch,
        DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch,
      );

      final firstPage =
          await repo.pagedOrdersInRange(range, limit: 2);
      expect(firstPage, hasLength(2));
      // 倒序：先拿到最新两笔
      expect(firstPage[0].id, 3);
      expect(firstPage[1].id, 2);

      final secondPage = await repo.pagedOrdersInRange(
        range,
        limit: 2,
        cursorCreatedAt: firstPage.last.createdAtMs,
        cursorId: firstPage.last.id,
      );
      expect(secondPage.single.id, 1);
    });
  });

  group('聚合查询', () {
    test('summary 按区间统计总额与订单数', () async {
      await seedProduct(id: 1, name: '肉锅贴', priceCents: 80);
      await seedProduct(id: 3, name: '豆浆', priceCents: 200);

      // 两笔订单落在 10 月 1 日
      await repo.checkout([
        const OrderLine(product: Product(id: 1, name: '肉锅贴', priceCents: 80), quantity: 1),
      ]);
      await repo.checkout([
        const OrderLine(product: Product(id: 3, name: '豆浆', priceCents: 200), quantity: 1),
      ]);

      // 订单时间由 checkout 取 DateTime.now()，区间按当天构造
      final day = DateTime.now();
      final summary = await repo.summary(
        DateRange(
          DateTime(day.year, day.month, day.day).millisecondsSinceEpoch,
          DateTime(day.year, day.month, day.day + 1).millisecondsSinceEpoch,
        ),
      );
      expect(summary.orderCount, 2);
      expect(summary.totalCents, 280);
      expect(summary.avgCents, 140);
    });
  });
}
