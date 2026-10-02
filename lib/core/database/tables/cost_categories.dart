import 'package:drift/drift.dart';

/// 成本类目，如「猪肉」「面粉」「粉丝」
class CostCategories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().unique()();

  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  /// 软删除标记
  IntColumn get isActive => integer().withDefault(const Constant(1))();
}
