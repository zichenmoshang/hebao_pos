import 'package:drift/drift.dart';

/// 订单（结账记录）
@TableIndex(name: 'idx_orders_created_at', columns: {#createdAt})
class Orders extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 订单总额（分），结账时快照
  IntColumn get totalCents => integer()();

  /// 结账时间（Unix 毫秒时间戳）
  IntColumn get createdAt => integer()();
}
