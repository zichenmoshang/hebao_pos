import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/database/app_database.dart' hide Product;
import 'package:hebao_pos/core/database/app_database_provider.dart';
import 'package:hebao_pos/core/repositories/order_repository.dart';
import 'package:hebao_pos/features/cashier/providers/today_summary_provider.dart';
import 'package:hebao_pos/shared/models/order_line.dart';
import 'package:hebao_pos/shared/models/product.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late OrderRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    repo = OrderRepository(db);
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: const Value(1),
            name: '肉锅贴',
            priceCents: 80,
            createdAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> checkout(int quantity) => repo.checkout([
        OrderLine(
          product: const Product(id: 1, name: '肉锅贴', priceCents: 80),
          quantity: quantity,
        ),
      ]);

  test('无订单时当日流水为 0', () async {
    final summary = await container.read(todaySummaryProvider.future);
    expect(summary.totalCents, 0);
    expect(summary.orderCount, 0);
  });

  test('结账后聚合当日营业额与订单数，invalidate 后刷新', () async {
    await checkout(2);
    await checkout(1);

    var summary = await container.read(todaySummaryProvider.future);
    expect(summary.totalCents, 240);
    expect(summary.orderCount, 2);

    await checkout(3);
    container.invalidate(todaySummaryProvider);

    summary = await container.read(todaySummaryProvider.future);
    expect(summary.totalCents, 480);
    expect(summary.orderCount, 3);
  });
}
