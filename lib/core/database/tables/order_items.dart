import 'package:drift/drift.dart';

import 'orders.dart';
import 'products.dart';

/// 订单明细：商品名称、单价做快照，商品后续改名/改价不影响历史
@TableIndex(name: 'idx_items_order_id', columns: {#orderId})
@TableIndex(name: 'idx_items_product_id', columns: {#productId})
class OrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 所属订单，级联删除
  IntColumn get orderId =>
      integer().references(Orders, #id, onDelete: KeyAction.cascade)();

  /// 成交商品
  IntColumn get productId => integer().references(Products, #id)();

  /// 名称快照
  TextColumn get productName => text()();

  /// 成交单价快照（分）
  IntColumn get unitPriceCents => integer()();

  /// 数量
  IntColumn get quantity => integer()();

  /// 该行小计（分）
  IntColumn get lineTotalCents => integer()();
}
