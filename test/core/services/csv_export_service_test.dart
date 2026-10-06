import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/database/app_database.dart' hide Product;
import 'package:hebao_pos/core/database/app_database_provider.dart';
import 'package:hebao_pos/core/repositories/cost_repository.dart';
import 'package:hebao_pos/core/repositories/order_repository.dart';
import 'package:hebao_pos/core/services/csv_export_service.dart';
import 'package:hebao_pos/core/utils/date_range.dart';
import 'package:hebao_pos/shared/models/order_line.dart';
import 'package:hebao_pos/shared/models/product.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.tempPath);

  final String tempPath;

  @override
  Future<String?> getTemporaryPath() async => tempPath;
}

class _FakeSharePlatform extends SharePlatform {
  ShareParams? lastParams;

  @override
  Future<ShareResult> share(ShareParams params) async {
    lastParams = params;
    return ShareResult.unavailable;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;
  late Directory tempDir;

  // SharePlus.instance 为 static final，首次访问即固定平台实例，
  // 因此整个文件共用一份 fake，每个用例只重置记录
  final fakeShare = _FakeSharePlatform();

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(db),
    ]);
    tempDir = Directory.systemTemp.createTempSync('hebao_export_test');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    fakeShare.lastParams = null;
    SharePlatform.instance = fakeShare;
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<int> seedOrder() async {
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: const Value(1),
            name: '肉锅贴',
            priceCents: 80,
            createdAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
          ),
        );
    return OrderRepository(db).checkout([
      const OrderLine(
        product: Product(id: 1, name: '肉锅贴', priceCents: 80),
        quantity: 2,
      ),
    ]);
  }

  Future<void> seedCost() async {
    final categoryId = await db.into(db.costCategories).insert(
          CostCategoriesCompanion.insert(name: '猪肉'),
        );
    await CostRepository(db).addRecord(
      categoryId: categoryId,
      amountCents: 5000,
      occurredOn: DateTime.now(),
      note: '早市采购',
    );
  }

  CsvExportService service() => container.read(csvExportServiceProvider);

  test('区间内无订单且无成本时抛 ExportEmptyException', () async {
    final now = DateTime.now();
    await expectLater(
      service().export(dayRange(now), now, now),
      throwsA(isA<ExportEmptyException>()),
    );
  });

  test('导出三个工作表并通过分享发出 xlsx 文件', () async {
    final orderId = await seedOrder();
    await seedCost();

    final now = DateTime.now();
    await service().export(dayRange(now), now, now);

    // 分享参数携带生成的 xlsx
    final params = fakeShare.lastParams;
    expect(params, isNotNull);
    expect(params!.files, hasLength(1));

    final file = File(params.files!.single.path);
    expect(file.parent.path, tempDir.path);
    expect(file.existsSync(), isTrue);

    final excel = Excel.decodeBytes(await file.readAsBytes());
    expect(excel.tables.keys,
        containsAll(['订单汇总', '订单明细', '成本采购']));

    // 表头 + 一条数据
    expect(excel['订单汇总'].rows, hasLength(2));
    expect(excel['订单明细'].rows, hasLength(2));
    expect(excel['成本采购'].rows, hasLength(2));

    // 订单号与总额写入正确（80 分 x 2 = ¥1.6）
    final summaryRow = excel['订单汇总'].rows[1];
    expect((summaryRow[0]?.value as IntCellValue).value, orderId);
    expect((summaryRow[2]?.value as DoubleCellValue).value, 1.6);
  });

  test('只有成本数据时删除订单相关空表', () async {
    await seedCost();

    final now = DateTime.now();
    await service().export(dayRange(now), now, now);

    final file = File(fakeShare.lastParams!.files!.single.path);
    final excel = Excel.decodeBytes(await file.readAsBytes());
    expect(excel.tables.keys, ['成本采购']);
    expect(excel['成本采购'].rows, hasLength(2));
  });
}
