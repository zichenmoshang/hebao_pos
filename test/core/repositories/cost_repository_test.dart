import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/database/app_database.dart' hide CostCategory;
import 'package:hebao_pos/core/repositories/cost_repository.dart';
import 'package:hebao_pos/core/utils/date_range.dart';

void main() {
  late AppDatabase db;
  late CostRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = CostRepository(db);
  });

  tearDown(() => db.close());

  Future<int> seedCategory(
    String name, {
    int sortIndex = 0,
    int isActive = 1,
  }) {
    return db.into(db.costCategories).insert(
          CostCategoriesCompanion.insert(
            name: name,
            sortIndex: Value(sortIndex),
            isActive: Value(isActive),
          ),
        );
  }

  Future<int> seedRecord({
    required int categoryId,
    required int amountCents,
    required DateTime occurredOn,
    String? note,
  }) {
    return db.into(db.costRecords).insert(
          CostRecordsCompanion.insert(
            categoryId: categoryId,
            amountCents: amountCents,
            occurredOn: DateTime(occurredOn.year, occurredOn.month,
                    occurredOn.day)
                .millisecondsSinceEpoch,
            note: Value(note),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  /// 覆盖 2026-10-01 ~ 2026-10-07（含）的区间
  DateRange weekRange() =>
      customRange(DateTime(2026, 10, 1), DateTime(2026, 10, 7));

  group('类目查询', () {
    test('activeCategories 只返回启用类目并按 sortIndex 升序', () async {
      await seedCategory('粉丝', sortIndex: 2);
      await seedCategory('猪肉', sortIndex: 0);
      await seedCategory('面粉', sortIndex: 1, isActive: 0);

      final categories = await repo.activeCategories();
      expect(categories.map((e) => e.name), ['猪肉', '粉丝']);
      expect(categories.every((e) => e.isActive), isTrue);
    });

    test('allCategories 启用的在前，组内按 sortIndex 升序', () async {
      await seedCategory('粉丝', sortIndex: 2);
      await seedCategory('猪肉', sortIndex: 1, isActive: 0);
      await seedCategory('面粉', sortIndex: 0);

      final categories = await repo.allCategories();
      expect(categories.map((e) => e.name), ['面粉', '粉丝', '猪肉']);
      expect(categories.map((e) => e.isActive), [true, true, false]);
    });
  });

  group('nameExists', () {
    test('同名启用类目返回 true', () async {
      await seedCategory('猪肉');
      expect(await repo.nameExists('猪肉'), isTrue);
      expect(await repo.nameExists('牛肉'), isFalse);
    });

    test('已软删类目不拦截同名', () async {
      await seedCategory('猪肉', isActive: 0);
      expect(await repo.nameExists('猪肉'), isFalse);
    });

    test('excludeId 排除自身', () async {
      final id = await seedCategory('猪肉');
      expect(await repo.nameExists('猪肉', excludeId: id), isFalse);
    });
  });

  group('类目维护', () {
    test('addCategory 依次排到末尾并返回 id', () async {
      final id1 = await repo.addCategory('猪肉');
      final id2 = await repo.addCategory('面粉');

      final categories = await repo.allCategories();
      expect(categories.map((e) => e.id), [id1, id2]);
      expect(categories.map((e) => e.name), ['猪肉', '面粉']);
    });

    test('renameCategory 改名', () async {
      final id = await repo.addCategory('猪肉');
      await repo.renameCategory(id, '黑猪肉');

      final categories = await repo.allCategories();
      expect(categories.single.name, '黑猪肉');
    });

    test('deactivateCategory 软删除后不再出现于启用列表', () async {
      final id = await repo.addCategory('猪肉');
      await repo.deactivateCategory(id);

      expect(await repo.activeCategories(), isEmpty);
      expect((await repo.allCategories()).single.isActive, isFalse);
    });
  });

  group('采购记录维护', () {
    test('addRecord 将发生时间截断到当日 0 点并保存备注', () async {
      final categoryId = await seedCategory('猪肉');
      final id = await repo.addRecord(
        categoryId: categoryId,
        amountCents: 5000,
        occurredOn: DateTime(2026, 10, 3, 15, 30),
        note: '早市采购',
      );

      final records = await repo.recordsInRange(weekRange());
      expect(records.single.id, id);
      expect(records.single.occurredOnMs,
          DateTime(2026, 10, 3).millisecondsSinceEpoch);
      expect(records.single.occurredOn, DateTime(2026, 10, 3));
      expect(records.single.note, '早市采购');
      expect(records.single.categoryName, '猪肉');
    });

    test('updateRecord 修改金额、类目、日期与备注', () async {
      final pork = await seedCategory('猪肉');
      final flour = await seedCategory('面粉');
      final id = await repo.addRecord(
        categoryId: pork,
        amountCents: 5000,
        occurredOn: DateTime(2026, 10, 3),
      );

      await repo.updateRecord(
        id: id,
        categoryId: flour,
        amountCents: 3200,
        occurredOn: DateTime(2026, 10, 5),
        note: '改单',
      );

      final records = await repo.recordsInRange(weekRange());
      expect(records.single.categoryId, flour);
      expect(records.single.categoryName, '面粉');
      expect(records.single.amountCents, 3200);
      expect(records.single.occurredOnMs,
          DateTime(2026, 10, 5).millisecondsSinceEpoch);
      expect(records.single.note, '改单');
    });

    test('deleteRecord 删除记录', () async {
      final categoryId = await seedCategory('猪肉');
      final id = await repo.addRecord(
        categoryId: categoryId,
        amountCents: 5000,
        occurredOn: DateTime(2026, 10, 3),
      );

      await repo.deleteRecord(id);
      expect(await repo.recordsInRange(weekRange()), isEmpty);
    });
  });

  group('区间聚合', () {
    test('totalInRange 汇总区间内金额，区间外不计', () async {
      final categoryId = await seedCategory('猪肉');
      await seedRecord(
          categoryId: categoryId,
          amountCents: 1000,
          occurredOn: DateTime(2026, 10, 1));
      await seedRecord(
          categoryId: categoryId,
          amountCents: 2000,
          occurredOn: DateTime(2026, 10, 7));
      await seedRecord(
          categoryId: categoryId,
          amountCents: 4000,
          occurredOn: DateTime(2026, 10, 8));

      expect(await repo.totalInRange(weekRange()), 3000);
    });

    test('totalInRange 无记录返回 0', () async {
      expect(await repo.totalInRange(weekRange()), 0);
    });

    test('recordsInRange 按发生日期倒序、同日按 id 倒序', () async {
      final categoryId = await seedCategory('猪肉');
      final id1 = await seedRecord(
          categoryId: categoryId,
          amountCents: 1000,
          occurredOn: DateTime(2026, 10, 2));
      final id2 = await seedRecord(
          categoryId: categoryId,
          amountCents: 2000,
          occurredOn: DateTime(2026, 10, 5));
      final id3 = await seedRecord(
          categoryId: categoryId,
          amountCents: 3000,
          occurredOn: DateTime(2026, 10, 5));

      final records = await repo.recordsInRange(weekRange());
      expect(records.map((e) => e.id), [id3, id2, id1]);
    });

    test('categoryBreakdown 按金额降序聚合，含已软删类目', () async {
      final pork = await seedCategory('猪肉', sortIndex: 0);
      final flour = await seedCategory('面粉', sortIndex: 1);
      await seedRecord(
          categoryId: pork,
          amountCents: 1000,
          occurredOn: DateTime(2026, 10, 2));
      await seedRecord(
          categoryId: pork,
          amountCents: 2000,
          occurredOn: DateTime(2026, 10, 3));
      await seedRecord(
          categoryId: flour,
          amountCents: 5000,
          occurredOn: DateTime(2026, 10, 3));
      await repo.deactivateCategory(pork);

      final breakdown = await repo.categoryBreakdown(weekRange());
      expect(breakdown.map((e) => e.name), ['面粉', '猪肉']);
      expect(breakdown.map((e) => e.amountCents), [5000, 3000]);
    });
  });

  group('pagedRecordsInRange', () {
    test('游标正确接续下一页', () async {
      final categoryId = await seedCategory('猪肉');
      for (var i = 0; i < 3; i++) {
        await seedRecord(
          categoryId: categoryId,
          amountCents: 100 * (i + 1),
          occurredOn: DateTime(2026, 10, 2 + i),
        );
      }

      final firstPage = await repo.pagedRecordsInRange(weekRange(), limit: 2);
      expect(firstPage, hasLength(2));
      expect(firstPage[0].amountCents, 300);
      expect(firstPage[1].amountCents, 200);

      final secondPage = await repo.pagedRecordsInRange(
        weekRange(),
        limit: 2,
        cursorOccurredOn: firstPage.last.occurredOnMs,
        cursorId: firstPage.last.id,
      );
      expect(secondPage.single.amountCents, 100);
    });

    test('同日多条记录按 id 倒序翻页不丢不重', () async {
      final categoryId = await seedCategory('猪肉');
      final ids = <int>[
        for (var i = 0; i < 3; i++)
          await seedRecord(
            categoryId: categoryId,
            amountCents: 100 * (i + 1),
            occurredOn: DateTime(2026, 10, 2),
          ),
      ];

      final firstPage = await repo.pagedRecordsInRange(weekRange(), limit: 2);
      expect(firstPage.map((e) => e.id), [ids[2], ids[1]]);

      final secondPage = await repo.pagedRecordsInRange(
        weekRange(),
        limit: 2,
        cursorOccurredOn: firstPage.last.occurredOnMs,
        cursorId: firstPage.last.id,
      );
      expect(secondPage.map((e) => e.id), [ids[0]]);
    });
  });
}
