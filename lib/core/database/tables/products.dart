import 'package:drift/drift.dart';

/// 商品表：删除用软删除（isActive），保留历史订单引用
class Products extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// 商品名，如「肉锅贴」
  TextColumn get name => text()();

  /// 单价（分）
  IntColumn get priceCents => integer()();

  /// 单位：个/杯/碗
  TextColumn get unit => text().withDefault(const Constant('个'))();

  /// 商品图片本地文件绝对路径；null 表示未设置
  TextColumn get imagePath => text().nullable()();

  /// 主界面排序
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  /// 软删除标记
  IntColumn get isActive => integer().withDefault(const Constant(1))();

  IntColumn get createdAt => integer()();
}
