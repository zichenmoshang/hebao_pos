import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart' as db;
import '../database/app_database_provider.dart';
import '../utils/date_range.dart';
import '../../shared/models/order_line.dart';

/// 区间概览聚合结果（分）
class OrderSummary {
  const OrderSummary({
    this.totalCents = 0,
    this.orderCount = 0,
  });

  final int totalCents;
  final int orderCount;

  /// 客单价（分）；无单为 0
  int get avgCents => orderCount == 0 ? 0 : totalCents ~/ orderCount;
}

/// 单品聚合行
class ProductSales {
  const ProductSales({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.amountCents,
  });

  final int productId;
  final String name;
  final int quantity;
  final int amountCents;
}

/// 单笔订单的明细行（订单详情展示用，含堂食/打包与交付状态）
class OrderItemRecord {
  const OrderItemRecord({
    required this.name,
    required this.quantity,
    required this.amountCents,
    required this.channel,
    required this.isDelivered,
  });

  final String name;
  final int quantity;
  final int amountCents;
  final OrderChannel channel;

  /// 打包行是否已交付；堂食行恒为 false
  final bool isDelivered;
}

/// 一条打包明细（待打包清单用），附带所属订单的下单时间
class TakeoutItem {
  const TakeoutItem({
    required this.itemId,
    required this.orderId,
    required this.productName,
    required this.quantity,
    required this.orderCreatedAtMs,
    this.deliveredAtMs,
  });

  final int itemId;
  final int orderId;
  final String productName;
  final int quantity;
  final int orderCreatedAtMs;
  final int? deliveredAtMs;

  DateTime get orderCreatedAt =>
      DateTime.fromMillisecondsSinceEpoch(orderCreatedAtMs);
}

/// 一笔订单明细的导出行（含成交单价快照）
class OrderItemDetail {
  const OrderItemDetail({
    required this.orderId,
    required this.productName,
    required this.unitPriceCents,
    required this.quantity,
    required this.lineTotalCents,
  });

  final int orderId;
  final String productName;
  final int unitPriceCents;
  final int quantity;
  final int lineTotalCents;
}

/// 一笔历史订单（列表展示用）
class OrderRecord {
  const OrderRecord({
    required this.id,
    required this.totalCents,
    required this.createdAtMs,
  });

  final int id;
  final int totalCents;
  final int createdAtMs;

  DateTime get createdAt =>
      DateTime.fromMillisecondsSinceEpoch(createdAtMs);
}

class OrderRepository {
  OrderRepository(this._db);

  final db.AppDatabase _db;

  /// 结账：单事务写入 orders + 全部明细，成功后返回订单 id
  Future<int> checkout(List<OrderLine> lines) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final total = lines.fold<int>(0, (sum, l) => sum + l.lineTotalCents);

    return _db.transaction<int>(() async {
      final orderId = await _db.into(_db.orders).insert(
            db.OrdersCompanion.insert(
              totalCents: total,
              createdAt: now,
            ),
          );
      await _db.batch((batch) {
        batch.insertAll(
          _db.orderItems,
          [
            for (final line in lines)
              db.OrderItemsCompanion.insert(
                orderId: orderId,
                productId: line.product.id,
                productName: line.product.name,
                unitPriceCents: line.product.priceCents,
                quantity: line.quantity,
                lineTotalCents: line.lineTotalCents,
                channel: Value(line.channel.dbValue),
              ),
          ],
        );
      });
      return orderId;
    });
  }

  /// 区间概览：营业额 + 订单数
  Future<OrderSummary> summary(DateRange range) async {
    final query = _db.selectOnly(_db.orders)
      ..addColumns([
        _db.orders.totalCents.sum(),
        _db.orders.id.count(),
      ])
      ..where(_db.orders.createdAt.isBetweenValues(range.start, range.end - 1));

    final row = await query.getSingle();
    return OrderSummary(
      totalCents: row.read(_db.orders.totalCents.sum()) ?? 0,
      orderCount: row.read(_db.orders.id.count()) ?? 0,
    );
  }

  /// 区间内每日营业额：返回「距起点第 n 天 -> 金额(分)」，无数据日不出现
  Future<Map<int, int>> dailyRevenue(DateRange range) async {
    final query = _db.selectOnly(_db.orders)
      ..addColumns([
        _db.orders.createdAt,
        _db.orders.totalCents.sum(),
      ])
      ..where(_db.orders.createdAt.isBetweenValues(range.start, range.end - 1))
      ..groupBy([_db.orders.createdAt]);

    // createdAt 是精确毫秒，无法直接按日 group，改为取出后在 Dart 侧归并到日
    final rows = await query.get();
    final result = <int, int>{};
    for (final row in rows) {
      final ms = row.read(_db.orders.createdAt)!;
      final amount = row.read(_db.orders.totalCents.sum()) ?? 0;
      final day = DateTime.fromMillisecondsSinceEpoch(ms);
      final dayStart =
          DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      final index = (dayStart - range.start) ~/ Duration.millisecondsPerDay;
      result[index] = (result[index] ?? 0) + amount;
    }
    return result;
  }

  /// 区间单品销量聚合，按销售额降序
  Future<List<ProductSales>> productSales(DateRange range) async {
    final items = _db.orderItems;
    final orders = _db.orders;
    final query = _db.selectOnly(items)
      ..addColumns([
        items.productId,
        items.productName,
        items.quantity.sum(),
        items.lineTotalCents.sum(),
      ])
      ..join([innerJoin(orders, orders.id.equalsExp(items.orderId))])
      ..where(orders.createdAt.isBetweenValues(range.start, range.end - 1))
      ..groupBy([items.productId])
      ..orderBy([
        OrderingTerm(
          expression: items.lineTotalCents.sum(),
          mode: OrderingMode.desc,
        ),
      ]);

    final rows = await query.get();
    return [
      for (final row in rows)
        ProductSales(
          productId: row.read(items.productId)!,
          name: row.read(items.productName)!,
          quantity: row.read(items.quantity.sum()) ?? 0,
          amountCents: row.read(items.lineTotalCents.sum()) ?? 0,
        ),
    ];
  }

  /// 某商品在区间内每日销量：「距起点第 n 天 -> 数量」
  Future<Map<int, int>> dailyProductQuantity(
      int productId, DateRange range) async {
    final items = _db.orderItems;
    final orders = _db.orders;
    final query = _db.selectOnly(items)
      ..addColumns([orders.createdAt, items.quantity.sum()])
      ..join([innerJoin(orders, orders.id.equalsExp(items.orderId))])
      ..where(
        items.productId.equals(productId) &
            orders.createdAt.isBetweenValues(range.start, range.end - 1),
      )
      ..groupBy([orders.createdAt]);

    final rows = await query.get();
    final result = <int, int>{};
    for (final row in rows) {
      final ms = row.read(orders.createdAt)!;
      final qty = row.read(items.quantity.sum()) ?? 0;
      final day = DateTime.fromMillisecondsSinceEpoch(ms);
      final dayStart =
          DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
      final index = (dayStart - range.start) ~/ Duration.millisecondsPerDay;
      result[index] = (result[index] ?? 0) + qty;
    }
    return result;
  }

  /// 区间订单列表，按时间倒序
  Future<List<OrderRecord>> ordersInRange(DateRange range) async {
    final rows = await (_db.select(_db.orders)
          ..where((t) =>
              t.createdAt.isBetweenValues(range.start, range.end - 1))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
    return [
      for (final r in rows)
        OrderRecord(
          id: r.id,
          totalCents: r.totalCents,
          createdAtMs: r.createdAt,
        ),
    ];
  }

  /// 取某订单明细（商品名 x 数量，含堂食/打包与交付状态）
  Future<List<OrderItemRecord>> itemsOfOrder(int orderId) async {
    final rows = await (_db.select(_db.orderItems)
          ..where((t) => t.orderId.equals(orderId)))
        .get();
    return [
      for (final r in rows)
        OrderItemRecord(
          name: r.productName,
          quantity: r.quantity,
          amountCents: r.lineTotalCents,
          channel: OrderChannel.fromDb(r.channel),
          isDelivered: r.deliveredAt != null,
        ),
    ];
  }

  /// 待打包清单：未交付的打包明细，按下单时间升序（先下单的先交付）
  Future<List<TakeoutItem>> pendingTakeoutItems() async {
    final items = _db.orderItems;
    final orders = _db.orders;
    final query = _db.select(items).join([
      innerJoin(orders, orders.id.equalsExp(items.orderId)),
    ])
      ..where(items.channel.equals('takeout') & items.deliveredAt.isNull())
      ..orderBy([OrderingTerm.asc(orders.createdAt)]);
    final rows = await query.get();
    return [
      for (final row in rows)
        _toTakeoutItem(row.readTable(items), row.readTable(orders)),
    ];
  }

  /// 最近已交付的打包明细（清单内撤销用），按交付时间倒序
  Future<List<TakeoutItem>> deliveredTakeoutItems({int limit = 20}) async {
    final items = _db.orderItems;
    final orders = _db.orders;
    final query = _db.select(items).join([
      innerJoin(orders, orders.id.equalsExp(items.orderId)),
    ])
      ..where(items.channel.equals('takeout') & items.deliveredAt.isNotNull())
      ..orderBy([OrderingTerm.desc(items.deliveredAt)])
      ..limit(limit);
    final rows = await query.get();
    return [
      for (final row in rows)
        _toTakeoutItem(row.readTable(items), row.readTable(orders)),
    ];
  }

  /// 标记打包明细已交付
  Future<void> markTakeoutDelivered(int itemId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.orderItems)..where((t) => t.id.equals(itemId)))
        .write(db.OrderItemsCompanion(deliveredAt: Value(now)));
  }

  /// 撤销交付：回到待打包状态
  Future<void> markTakeoutUndelivered(int itemId) async {
    await (_db.update(_db.orderItems)..where((t) => t.id.equals(itemId)))
        .write(const db.OrderItemsCompanion(deliveredAt: Value(null)));
  }

  TakeoutItem _toTakeoutItem(db.OrderItem item, db.Order order) {
    return TakeoutItem(
      itemId: item.id,
      orderId: item.orderId,
      productName: item.productName,
      quantity: item.quantity,
      orderCreatedAtMs: order.createdAt,
      deliveredAtMs: item.deliveredAt,
    );
  }

  /// 一次性取多笔订单的全部明细（消除导出时逐订单查询的 N+1），
  /// 直接带出成交单价快照，无需用行小计反推
  Future<List<OrderItemDetail>> itemsOfOrders(List<int> orderIds) async {
    if (orderIds.isEmpty) return const [];
    final rows = await (_db.select(_db.orderItems)
          ..where((t) => t.orderId.isIn(orderIds)))
        .get();
    return [
      for (final r in rows)
        OrderItemDetail(
          orderId: r.orderId,
          productName: r.productName,
          unitPriceCents: r.unitPriceCents,
          quantity: r.quantity,
          lineTotalCents: r.lineTotalCents,
        ),
    ];
  }

  /// 删除订单（级联删除明细）
  Future<void> deleteOrder(int orderId) async {
    await (_db.delete(_db.orders)..where((t) => t.id.equals(orderId))).go();
  }

  /// 游标分页取区间订单（倒序）。
  /// [cursorCreatedAt]/[cursorId] 为上一页最后一条，null 取首页；
  /// 用 (createdAt, id) 复合游标处理同一毫秒多条，每页 [limit] 条。
  Future<List<OrderRecord>> pagedOrdersInRange(
    DateRange range, {
    required int limit,
    int? cursorCreatedAt,
    int? cursorId,
  }) async {
    final q = _db.select(_db.orders)
      ..where((t) =>
          t.createdAt.isBetweenValues(range.start, range.end - 1))
      ..orderBy([
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
      ])
      ..limit(limit);

    final cc = cursorCreatedAt;
    final ci = cursorId;
    if (cc != null && ci != null) {
      // 倒序下一页：createdAt 更小，或同毫秒 id 更小
      q.where((t) =>
          t.createdAt.isSmallerThanValue(cc) |
          (t.createdAt.equals(cc) & t.id.isSmallerThanValue(ci)));
    }
    final rows = await q.get();
    return [
      for (final r in rows)
        OrderRecord(id: r.id, totalCents: r.totalCents, createdAtMs: r.createdAt),
    ];
  }
}

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(ref.watch(appDatabaseProvider));
});
