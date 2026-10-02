import 'package:drift/drift.dart';

import 'connection.dart';
import 'tables/cost_categories.dart';
import 'tables/cost_records.dart';
import 'tables/order_items.dart';
import 'tables/orders.dart';
import 'tables/products.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Products,
  Orders,
  OrderItems,
  CostCategories,
  CostRecords,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());

  /// 测试或自定义连接时使用
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          // 开启外键约束（SQLite 默认关闭）
          await customStatement('PRAGMA foreign_keys = ON');
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (m, from, to) async {
          // v1 -> v2：products 增加图片路径列
          if (from < 2) {
            await m.addColumn(products, products.imagePath);
          }
        },
      );

  /// 清空全部业务数据（订单、商品、成本）。
  /// 在单事务内按外键依赖顺序删除；设置项（shared_preferences）不在此处理。
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(orderItems).go();
      await delete(orders).go();
      await delete(costRecords).go();
      await delete(costCategories).go();
      await delete(products).go();
    });
  }
}
