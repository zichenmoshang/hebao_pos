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

  /// 以指定时间直接插入订单（checkout 的时间固定为 now，历史数据用此构造）
  Future<int> insertOrder({
    required int totalCents,
    required DateTime createdAt,
  }) {
    return db.into(db.orders).insert(
          OrdersCompanion.insert(
            totalCents: totalCents,
            createdAt: createdAt.millisecondsSinceEpoch,
          ),
        );
  }

  Future<void> insertItem({
    required int orderId,
    required int productId,
    required String name,
    required int unitPriceCents,
    required int quantity,
    String channel = 'dine_in',
  }) {
    return db.into(db.orderItems).insert(
          OrderItemsCompanion.insert(
            orderId: orderId,
            productId: productId,
            productName: name,
            unitPriceCents: unitPriceCents,
            quantity: quantity,
            lineTotalCents: unitPriceCents * quantity,
            channel: Value(channel),
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

    test('空区间 summary 全为 0，avgCents 不抛除零', () async {
      final day = DateTime.now();
      final summary = await repo.summary(dayRange(day));
      expect(summary.orderCount, 0);
      expect(summary.totalCents, 0);
      expect(summary.avgCents, 0);
    });

    test('summary 不计入区间外订单', () async {
      final day = DateTime.now();
      await insertOrder(totalCents: 100, createdAt: day);
      await insertOrder(
        totalCents: 900,
        createdAt: day.subtract(const Duration(days: 1)),
      );

      final summary = await repo.summary(dayRange(day));
      expect(summary.orderCount, 1);
      expect(summary.totalCents, 100);
    });
  });

  group('ordersInRange', () {
    test('按时间倒序返回区间内订单', () async {
      final base = DateTime(2026, 10, 2, 8);
      final id1 = await insertOrder(totalCents: 100, createdAt: base);
      final id2 = await insertOrder(
        totalCents: 200,
        createdAt: base.add(const Duration(hours: 1)),
      );
      final id3 = await insertOrder(
        totalCents: 300,
        createdAt: base.add(const Duration(hours: 2)),
      );
      // 区间外
      await insertOrder(
        totalCents: 900,
        createdAt: base.subtract(const Duration(days: 2)),
      );

      final orders = await repo.ordersInRange(dayRange(base));
      expect(orders.map((e) => e.id), [id3, id2, id1]);
      expect(orders.map((e) => e.totalCents), [300, 200, 100]);
      expect(orders.first.createdAt, base.add(const Duration(hours: 2)));
    });
  });

  group('dailyRevenue', () {
    test('跨天订单按「距起点第 n 天」归并', () async {
      final start = DateTime(2026, 10, 1);
      await insertOrder(
        totalCents: 100,
        createdAt: start.add(const Duration(hours: 8)),
      );
      await insertOrder(
        totalCents: 200,
        createdAt: start.add(const Duration(hours: 20)),
      );
      await insertOrder(
        totalCents: 300,
        createdAt: start.add(const Duration(days: 2, hours: 9)),
      );

      final revenue = await repo.dailyRevenue(
        customRange(start, start.add(const Duration(days: 2))),
      );
      expect(revenue, {0: 300, 2: 300});
    });
  });

  group('productSales', () {
    test('跨订单聚合销量并按销售额降序', () async {
      await seedProduct(id: 1, name: '肉锅贴', priceCents: 80);
      await seedProduct(id: 3, name: '豆浆', priceCents: 200);

      final order1 = await insertOrder(
        totalCents: 360,
        createdAt: DateTime(2026, 10, 2, 8),
      );
      await insertItem(
        orderId: order1,
        productId: 1,
        name: '肉锅贴',
        unitPriceCents: 80,
        quantity: 2,
      );
      await insertItem(
        orderId: order1,
        productId: 3,
        name: '豆浆',
        unitPriceCents: 200,
        quantity: 1,
      );
      final order2 = await insertOrder(
        totalCents: 80,
        createdAt: DateTime(2026, 10, 2, 9),
      );
      await insertItem(
        orderId: order2,
        productId: 1,
        name: '肉锅贴',
        unitPriceCents: 80,
        quantity: 1,
      );

      final sales = await repo.productSales(dayRange(DateTime(2026, 10, 2)));
      expect(sales.map((e) => e.productId), [1, 3]);
      expect(sales.map((e) => e.quantity), [3, 1]);
      expect(sales.map((e) => e.amountCents), [240, 200]);
    });
  });

  group('dailyProductQuantity', () {
    test('只统计指定商品并按日归并', () async {
      await seedProduct(id: 1, name: '肉锅贴', priceCents: 80);
      await seedProduct(id: 3, name: '豆浆', priceCents: 200);
      final start = DateTime(2026, 10, 1);

      final order1 = await insertOrder(
        totalCents: 360,
        createdAt: start.add(const Duration(hours: 8)),
      );
      await insertItem(
        orderId: order1,
        productId: 1,
        name: '肉锅贴',
        unitPriceCents: 80,
        quantity: 2,
      );
      await insertItem(
        orderId: order1,
        productId: 3,
        name: '豆浆',
        unitPriceCents: 200,
        quantity: 1,
      );
      final order2 = await insertOrder(
        totalCents: 240,
        createdAt: start.add(const Duration(days: 2, hours: 9)),
      );
      await insertItem(
        orderId: order2,
        productId: 1,
        name: '肉锅贴',
        unitPriceCents: 80,
        quantity: 3,
      );

      final quantities = await repo.dailyProductQuantity(
        1,
        customRange(start, start.add(const Duration(days: 2))),
      );
      expect(quantities, {0: 2, 2: 3});
    });
  });

  group('itemsOfOrder', () {
    test('返回单笔订单的明细行', () async {
      await seedProduct(id: 1, name: '肉锅贴', priceCents: 80);
      await seedProduct(id: 3, name: '豆浆', priceCents: 200);

      final orderId = await repo.checkout([
        const OrderLine(
          product: Product(id: 1, name: '肉锅贴', priceCents: 80),
          quantity: 2,
        ),
        const OrderLine(
          product: Product(id: 3, name: '豆浆', priceCents: 200),
          quantity: 1,
        ),
      ]);

      final items = await repo.itemsOfOrder(orderId);
      expect(items, hasLength(2));
      expect(items.map((e) => e.name), ['肉锅贴', '豆浆']);
      expect(items.map((e) => e.quantity), [2, 1]);
      expect(items.map((e) => e.amountCents), [160, 200]);
    });
  });

  group('堂食/打包与待交付', () {
    test('checkout 写入通道；打包行默认待交付，堂食行无交付状态', () async {
      await seedProduct(id: 1, name: '肉锅贴', priceCents: 80);

      await repo.checkout([
        const OrderLine(
          product: Product(id: 1, name: '肉锅贴', priceCents: 80),
          quantity: 8,
        ),
        const OrderLine(
          product: Product(id: 1, name: '肉锅贴', priceCents: 80),
          quantity: 4,
          channel: OrderChannel.takeout,
        ),
      ]);

      final items = await db.select(db.orderItems).get();
      expect(items, hasLength(2));
      final dine = items.singleWhere((e) => e.channel == 'dine_in');
      final take = items.singleWhere((e) => e.channel == 'takeout');
      expect(dine.quantity, 8);
      expect(dine.deliveredAt, isNull);
      expect(take.quantity, 4);
      expect(take.deliveredAt, isNull);
    });

    test('pendingTakeoutItems 只含未交付打包行，按下单时间升序', () async {
      await seedProduct(id: 1, name: '肉锅贴', priceCents: 80);
      final base = DateTime(2026, 10, 2, 8);
      final later = await insertOrder(totalCents: 80, createdAt: base);
      final earlier =
          await insertOrder(totalCents: 160, createdAt: base.subtract(
        const Duration(hours: 1),
      ));
      // 堂食行不应出现
      await insertItem(
        orderId: earlier,
        productId: 1,
        name: '肉锅贴',
        unitPriceCents: 80,
        quantity: 2,
      );
      await insertItem(
        orderId: earlier,
        productId: 1,
        name: '肉锅贴',
        unitPriceCents: 80,
        quantity: 1,
        channel: 'takeout',
      );
      await insertItem(
        orderId: later,
        productId: 1,
        name: '肉锅贴',
        unitPriceCents: 80,
        quantity: 3,
        channel: 'takeout',
      );

      final pending = await repo.pendingTakeoutItems();
      expect(pending.map((e) => e.quantity), [1, 3]);
      expect(pending.first.orderCreatedAt.hour, 7);
    });

    test('交付后移出待打包并进入已交付列表，可撤销恢复', () async {
      await seedProduct(id: 1, name: '肉锅贴', priceCents: 80);
      final orderId = await repo.checkout([
        const OrderLine(
          product: Product(id: 1, name: '肉锅贴', priceCents: 80),
          quantity: 4,
          channel: OrderChannel.takeout,
        ),
      ]);
      final itemId = (await repo.pendingTakeoutItems()).single.itemId;

      await repo.markTakeoutDelivered(itemId);
      expect(await repo.pendingTakeoutItems(), isEmpty);
      final delivered = await repo.deliveredTakeoutItems();
      expect(delivered.single.itemId, itemId);
      expect(delivered.single.orderId, orderId);
      expect(delivered.single.deliveredAtMs, isNotNull);

      await repo.markTakeoutUndelivered(itemId);
      expect(await repo.deliveredTakeoutItems(), isEmpty);
      expect((await repo.pendingTakeoutItems()).single.itemId, itemId);
    });

    test('itemsOfOrder 带回堂/外标记与交付状态', () async {
      await seedProduct(id: 1, name: '肉锅贴', priceCents: 80);
      final orderId = await repo.checkout([
        const OrderLine(
          product: Product(id: 1, name: '肉锅贴', priceCents: 80),
          quantity: 8,
        ),
        const OrderLine(
          product: Product(id: 1, name: '肉锅贴', priceCents: 80),
          quantity: 4,
          channel: OrderChannel.takeout,
        ),
      ]);

      final items = await repo.itemsOfOrder(orderId);
      final dine =
          items.singleWhere((e) => e.channel == OrderChannel.dineIn);
      final take =
          items.singleWhere((e) => e.channel == OrderChannel.takeout);
      expect(dine.isDelivered, isFalse);
      expect(take.isDelivered, isFalse);
    });
  });

  group('deleteOrder', () {
    test('删除订单并级联删除明细，不影响其他订单', () async {
      await seedProduct(id: 1, name: '肉锅贴', priceCents: 80);
      final id1 = await repo.checkout([
        const OrderLine(
          product: Product(id: 1, name: '肉锅贴', priceCents: 80),
          quantity: 1,
        ),
      ]);
      final id2 = await repo.checkout([
        const OrderLine(
          product: Product(id: 1, name: '肉锅贴', priceCents: 80),
          quantity: 2,
        ),
      ]);

      await repo.deleteOrder(id1);

      final orders = await db.select(db.orders).get();
      expect(orders.single.id, id2);
      final items = await db.select(db.orderItems).get();
      expect(items.single.orderId, id2);
    });
  });
}
