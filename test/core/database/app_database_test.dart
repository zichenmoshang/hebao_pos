import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('clearAllData', () {
    test('清空全部业务表且之后可正常写入', () async {
      final productId = await db.into(db.products).insert(
            ProductsCompanion.insert(
              name: '肉锅贴',
              priceCents: 80,
              createdAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
            ),
          );
      final categoryId = await db.into(db.costCategories).insert(
            CostCategoriesCompanion.insert(name: '猪肉'),
          );
      await db.into(db.costRecords).insert(
            CostRecordsCompanion.insert(
              categoryId: categoryId,
              amountCents: 5000,
              occurredOn: DateTime(2026, 10, 1).millisecondsSinceEpoch,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      final orderId = await db.into(db.orders).insert(
            OrdersCompanion.insert(
              totalCents: 160,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      await db.into(db.orderItems).insert(
            OrderItemsCompanion.insert(
              orderId: orderId,
              productId: productId,
              productName: '肉锅贴',
              unitPriceCents: 80,
              quantity: 2,
              lineTotalCents: 160,
            ),
          );

      await db.clearAllData();

      expect(await db.select(db.products).get(), isEmpty);
      expect(await db.select(db.orders).get(), isEmpty);
      expect(await db.select(db.orderItems).get(), isEmpty);
      expect(await db.select(db.costCategories).get(), isEmpty);
      expect(await db.select(db.costRecords).get(), isEmpty);

      // 清空后外键等约束不受影响，可继续写入
      final newProductId = await db.into(db.products).insert(
            ProductsCompanion.insert(
              name: '豆浆',
              priceCents: 200,
              unit: const Value('杯'),
              createdAt: DateTime(2026, 10, 2).millisecondsSinceEpoch,
            ),
          );
      expect(newProductId, greaterThan(0));
    });
  });
}
