import 'package:drift/drift.dart';

import 'cost_categories.dart';

/// 原材料采购记录
@TableIndex(name: 'idx_cost_occurred_on', columns: {#occurredOn})
@TableIndex(name: 'idx_cost_category', columns: {#categoryId})
class CostRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 所属类目
  IntColumn get categoryId => integer().references(CostCategories, #id)();

  /// 采购金额（分）
  IntColumn get amountCents => integer()();

  /// 采购发生日期（当日 0 点毫秒时间戳，便于按日聚合）
  IntColumn get occurredOn => integer()();

  /// 选填备注
  TextColumn get note => text().nullable()();

  IntColumn get createdAt => integer()();
}
