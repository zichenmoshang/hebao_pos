import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart' as db;
import '../database/app_database_provider.dart';
import '../utils/date_range.dart';

/// 成本类目（领域模型）
class CostCategory {
  const CostCategory({
    required this.id,
    required this.name,
    required this.isActive,
  });

  final int id;
  final String name;
  final bool isActive;
}

/// 一笔采购记录（列表展示用）
class CostRecord {
  const CostRecord({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amountCents,
    required this.occurredOnMs,
    this.note,
  });

  final int id;
  final int categoryId;
  final String categoryName;
  final int amountCents;
  final int occurredOnMs;
  final String? note;

  /// 采购发生日期（当日 0 点）
  DateTime get occurredOn =>
      DateTime.fromMillisecondsSinceEpoch(occurredOnMs);
}

/// 类目采购额分布行
class CategoryCost {
  const CategoryCost({
    required this.categoryId,
    required this.name,
    required this.amountCents,
  });

  final int categoryId;
  final String name;
  final int amountCents;
}

class CostRepository {
  CostRepository(this._db);

  final db.AppDatabase _db;

  /// 全部启用类目，按排序字段升序（供记录表单选择）
  Future<List<CostCategory>> activeCategories() async {
    final rows = await (_db.select(_db.costCategories)
          ..where((t) => t.isActive.equals(1))
          ..orderBy([(t) => OrderingTerm(expression: t.sortIndex)]))
        .get();
    return rows.map(_toCategory).toList();
  }

  /// 全部类目（含已软删），供类目管理页
  Future<List<CostCategory>> allCategories() async {
    final rows = await (_db.select(_db.costCategories)
          ..orderBy([
            (t) => OrderingTerm(expression: t.isActive, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.sortIndex),
          ]))
        .get();
    return rows.map(_toCategory).toList();
  }

  /// 是否存在同名启用类目（重名拦截）；excludeId 用于改名时排除自身
  Future<bool> nameExists(String name, {int? excludeId}) async {
    final query = _db.select(_db.costCategories)
      ..where((t) => t.name.equals(name) & t.isActive.equals(1));
    if (excludeId != null) {
      query.where((t) => t.id.equals(excludeId).not());
    }
    return await query.getSingleOrNull() != null;
  }

  /// 新增类目，返回 id
  Future<int> addCategory(String name) async {
    final count = await _db.costCategories.count().getSingle();
    return _db.into(_db.costCategories).insert(
          db.CostCategoriesCompanion.insert(
            name: name,
            sortIndex: Value(count),
          ),
        );
  }

  /// 类目改名
  Future<void> renameCategory(int id, String name) async {
    await (_db.update(_db.costCategories)..where((t) => t.id.equals(id)))
        .write(db.CostCategoriesCompanion(name: Value(name)));
  }

  /// 软删除类目（历史流水保留）
  Future<void> deactivateCategory(int id) async {
    await (_db.update(_db.costCategories)..where((t) => t.id.equals(id)))
        .write(const db.CostCategoriesCompanion(isActive: Value(0)));
  }

  /// 新增一笔采购，返回 id
  Future<int> addRecord({
    required int categoryId,
    required int amountCents,
    required DateTime occurredOn,
    String? note,
  }) async {
    final dayStart = DateTime(
      occurredOn.year,
      occurredOn.month,
      occurredOn.day,
    ).millisecondsSinceEpoch;
    final now = DateTime.now().millisecondsSinceEpoch;
    return _db.into(_db.costRecords).insert(
          db.CostRecordsCompanion.insert(
            categoryId: categoryId,
            amountCents: amountCents,
            occurredOn: dayStart,
            note: Value(note),
            createdAt: now,
          ),
        );
  }

  /// 修改一笔采购
  Future<void> updateRecord({
    required int id,
    required int categoryId,
    required int amountCents,
    required DateTime occurredOn,
    String? note,
  }) async {
    final dayStart = DateTime(
      occurredOn.year,
      occurredOn.month,
      occurredOn.day,
    ).millisecondsSinceEpoch;
    await (_db.update(_db.costRecords)..where((t) => t.id.equals(id))).write(
      db.CostRecordsCompanion(
        categoryId: Value(categoryId),
        amountCents: Value(amountCents),
        occurredOn: Value(dayStart),
        note: Value(note),
      ),
    );
  }

  /// 删除一笔采购
  Future<void> deleteRecord(int id) async {
    await (_db.delete(_db.costRecords)..where((t) => t.id.equals(id))).go();
  }

  /// 区间采购总额（分）
  Future<int> totalInRange(DateRange range) async {
    final query = _db.selectOnly(_db.costRecords)
      ..addColumns([_db.costRecords.amountCents.sum()])
      ..where(
        _db.costRecords.occurredOn.isBetweenValues(range.start, range.end - 1),
      );
    final row = await query.getSingle();
    return row.read(_db.costRecords.amountCents.sum()) ?? 0;
  }

  /// 区间采购流水，按发生日期倒序
  Future<List<CostRecord>> recordsInRange(DateRange range) async {
    final records = _db.costRecords;
    final categories = _db.costCategories;
    final query = _db.select(records).join([
      innerJoin(categories, categories.id.equalsExp(records.categoryId)),
    ])
      ..where(
        records.occurredOn.isBetweenValues(range.start, range.end - 1),
      )
      ..orderBy([
        OrderingTerm(expression: records.occurredOn, mode: OrderingMode.desc),
        OrderingTerm(expression: records.id, mode: OrderingMode.desc),
      ]);

    final rows = await query.get();
    return [
      for (final row in rows)
        CostRecord(
          id: row.readTable(records).id,
          categoryId: row.readTable(records).categoryId,
          categoryName: row.readTable(categories).name,
          amountCents: row.readTable(records).amountCents,
          occurredOnMs: row.readTable(records).occurredOn,
          note: row.readTable(records).note,
        ),
    ];
  }

  /// 区间采购额类目分布（含已软删类目），按金额降序
  Future<List<CategoryCost>> categoryBreakdown(DateRange range) async {
    final records = _db.costRecords;
    final categories = _db.costCategories;
    final query = _db.selectOnly(records)
      ..addColumns([
        records.categoryId,
        categories.name,
        records.amountCents.sum(),
      ])
      ..join([innerJoin(categories, categories.id.equalsExp(records.categoryId))])
      ..where(records.occurredOn.isBetweenValues(range.start, range.end - 1))
      ..groupBy([records.categoryId])
      ..orderBy([
        OrderingTerm(
          expression: records.amountCents.sum(),
          mode: OrderingMode.desc,
        ),
      ]);

    final rows = await query.get();
    return [
      for (final row in rows)
        CategoryCost(
          categoryId: row.read(records.categoryId)!,
          name: row.read(categories.name)!,
          amountCents: row.read(records.amountCents.sum()) ?? 0,
        ),
    ];
  }

  CostCategory _toCategory(db.CostCategory row) => CostCategory(
        id: row.id,
        name: row.name,
        isActive: row.isActive == 1,
      );

  /// 游标分页取区间采购流水（按发生日期、id 倒序）。
  /// [cursorOccurredOn]/[cursorId] 为上一页最后一条，null 取首页。
  Future<List<CostRecord>> pagedRecordsInRange(
    DateRange range, {
    required int limit,
    int? cursorOccurredOn,
    int? cursorId,
  }) async {
    final records = _db.costRecords;
    final categories = _db.costCategories;
    final q = _db.select(records).join([
      innerJoin(categories, categories.id.equalsExp(records.categoryId)),
    ])
      ..where(
        records.occurredOn.isBetweenValues(range.start, range.end - 1),
      )
      ..orderBy([
        OrderingTerm(expression: records.occurredOn, mode: OrderingMode.desc),
        OrderingTerm(expression: records.id, mode: OrderingMode.desc),
      ]);

    final co = cursorOccurredOn;
    final ci = cursorId;
    if (co != null && ci != null) {
      q.where(
        records.occurredOn.isSmallerThanValue(co) |
            (records.occurredOn.equals(co) & records.id.isSmallerThanValue(ci)),
      );
    }
    q.limit(limit);

    final rows = await q.get();
    return [
      for (final row in rows)
        CostRecord(
          id: row.readTable(records).id,
          categoryId: row.readTable(records).categoryId,
          categoryName: row.readTable(categories).name,
          amountCents: row.readTable(records).amountCents,
          occurredOnMs: row.readTable(records).occurredOn,
          note: row.readTable(records).note,
        ),
    ];
  }
}

final costRepositoryProvider = Provider<CostRepository>((ref) {
  return CostRepository(ref.watch(appDatabaseProvider));
});
