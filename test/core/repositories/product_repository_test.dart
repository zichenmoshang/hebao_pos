import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/database/app_database.dart' hide Product;
import 'package:hebao_pos/core/repositories/product_repository.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProductRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = ProductRepository(db);
  });

  tearDown(() => db.close());

  Future<void> seedProduct({
    required int id,
    required String name,
    required int priceCents,
    int sortIndex = 0,
    int isActive = 1,
  }) async {
    await db.into(db.products).insert(
          ProductsCompanion.insert(
            id: Value(id),
            name: name,
            priceCents: priceCents,
            sortIndex: Value(sortIndex),
            isActive: Value(isActive),
            createdAt: DateTime(2026, 10, 1).millisecondsSinceEpoch,
          ),
        );
  }

  group('查询', () {
    test('watchActive 只返回在售商品并按 sortIndex 升序', () async {
      await seedProduct(id: 1, name: '素锅贴', priceCents: 100, sortIndex: 2);
      await seedProduct(id: 2, name: '肉锅贴', priceCents: 80, sortIndex: 1);
      await seedProduct(
          id: 3, name: '豆浆', priceCents: 200, sortIndex: 0, isActive: 0);

      final products = await repo.watchActive();
      expect(products.map((e) => e.name), ['肉锅贴', '素锅贴']);
      expect(products.every((e) => e.isActive), isTrue);
    });

    test('watchAll 返回全部商品（含停用）', () async {
      await seedProduct(id: 1, name: '肉锅贴', priceCents: 80, sortIndex: 1);
      await seedProduct(
          id: 2, name: '豆浆', priceCents: 200, sortIndex: 0, isActive: 0);

      final products = await repo.watchAll();
      expect(products.map((e) => e.name), ['豆浆', '肉锅贴']);
      expect(products.map((e) => e.isActive), [false, true]);
    });
  });

  group('nameExists', () {
    test('同名商品返回 true，支持 excludeId 排除自身', () async {
      final id = await repo.add(name: '肉锅贴', priceCents: 80, unit: '个');
      expect(await repo.nameExists('肉锅贴'), isTrue);
      expect(await repo.nameExists('素锅贴'), isFalse);
      expect(await repo.nameExists('肉锅贴', excludeId: id), isFalse);
    });
  });

  group('维护', () {
    test('add 追加到排序末尾并保留单位与图片路径', () async {
      await seedProduct(id: 1, name: '肉锅贴', priceCents: 80, sortIndex: 5);
      final id = await repo.add(
        name: '豆浆',
        priceCents: 200,
        unit: '杯',
        imagePath: '/tmp/doujiang.jpg',
      );

      final products = await repo.watchAll();
      expect(products.last.id, id);
      expect(products.last.unit, '杯');
      expect(products.last.imagePath, '/tmp/doujiang.jpg');
    });

    test('updateProduct 修改名称、单价、单位与图片', () async {
      final id = await repo.add(name: '肉锅贴', priceCents: 80, unit: '个');
      await repo.updateProduct(
        id: id,
        name: '鲜虾锅贴',
        priceCents: 150,
        unit: '份',
        imagePath: '/tmp/new.jpg',
      );

      final product =
          (await repo.watchAll()).singleWhere((e) => e.id == id);
      expect(product.name, '鲜虾锅贴');
      expect(product.priceCents, 150);
      expect(product.unit, '份');
      expect(product.imagePath, '/tmp/new.jpg');
    });

    test('setActive 停用后不在在售列表，可重新启用', () async {
      final id = await repo.add(name: '肉锅贴', priceCents: 80, unit: '个');

      await repo.setActive(id, false);
      expect(await repo.watchActive(), isEmpty);
      expect((await repo.watchAll()).single.isActive, isFalse);

      await repo.setActive(id, true);
      expect((await repo.watchActive()).single.id, id);
    });

    test('reorder 按给定顺序重排', () async {
      final id1 = await repo.add(name: '肉锅贴', priceCents: 80, unit: '个');
      final id2 = await repo.add(name: '素锅贴', priceCents: 100, unit: '个');
      final id3 = await repo.add(name: '豆浆', priceCents: 200, unit: '杯');

      final all = await repo.watchAll();
      await repo.reorder([
        all.singleWhere((e) => e.id == id3),
        all.singleWhere((e) => e.id == id1),
        all.singleWhere((e) => e.id == id2),
      ]);

      final reordered = await repo.watchAll();
      expect(reordered.map((e) => e.id), [id3, id1, id2]);
    });
  });

  group('ensureSeeded', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('hebao_seed_test');
      PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('空库播种 6 个内置商品并复制内置图片，重复调用不再写入', () async {
      await repo.ensureSeeded();

      final products = await repo.watchAll();
      expect(products, hasLength(6));
      expect(products.map((e) => e.id), [1, 2, 3, 4, 5, 6]);
      expect(products.map((e) => e.name),
          ['肉锅贴', '素锅贴', '豆浆', '豆腐脑', '五香蛋', '白粥']);
      expect(products.map((e) => e.priceCents),
          [150, 100, 200, 300, 150, 200]);
      expect(products.map((e) => e.unit),
          ['个', '个', '杯', '碗', '个', '碗']);

      // 内置图片已复制到应用文档目录，数据库保存本地文件路径
      for (final product in products) {
        final path = product.imagePath;
        expect(path, isNotNull);
        expect(path, contains('product_images'));
        expect(File(path!).existsSync(), isTrue,
            reason: '${product.name} 的图片文件应存在');
      }

      // 已有数据时跳过，不重复播种
      await repo.ensureSeeded();
      expect(await repo.watchAll(), hasLength(6));
    });

    test('空库但首次播种后可继续 add，不冲突', () async {
      await repo.ensureSeeded();
      final id = await repo.add(name: '茶叶蛋', priceCents: 200, unit: '个');

      final products = await repo.watchAll();
      expect(products, hasLength(7));
      expect(products.last.id, id);
      expect(products.last.name, '茶叶蛋');
    });
  });
}
