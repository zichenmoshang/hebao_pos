import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/app_database.dart' as db;
import '../database/app_database_provider.dart';
import '../../shared/models/product.dart';

/// 固定 6 个品类的种子数据（id 与原硬编码保持一致）
const _seedProducts = [
  Product(id: 1, name: '肉锅贴', priceCents: 150),
  Product(id: 2, name: '素锅贴', priceCents: 100),
  Product(id: 3, name: '豆浆', priceCents: 200, unit: '杯'),
  Product(id: 4, name: '豆腐脑', priceCents: 300, unit: '碗'),
  Product(id: 5, name: '五香蛋', priceCents: 150),
  Product(id: 6, name: '白粥', priceCents: 200, unit: '碗'),
];

/// 种子商品内置图片（assets/images/products/ 下的文件名），按商品 id 对应
const _seedImageAssets = <int, String>{
  1: 'rou_guotie.jpg',
  2: 'su_guotie.jpg',
  3: 'doujiang.jpg',
  4: 'doufunao.jpg',
  5: 'wuxiangdan.jpg',
  6: 'baizhou.jpg',
};

class ProductRepository {
  ProductRepository(this._db);

  final db.AppDatabase _db;

  /// 首次启动时写入 6 个内置商品（含内置图片）；已有数据则跳过
  Future<void> ensureSeeded() async {
    final count = await _db.products.count().getSingle();
    if (count > 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    // 内置商品图随 App 打包在 assets，首次播种时复制到应用文档目录，
    // 使数据库中的 imagePath 与用户拍照所得一致（统一为本地文件路径）
    final imagePaths = <int, String>{};
    for (final entry in _seedImageAssets.entries) {
      imagePaths[entry.key] = await _copyBundledImage(entry.value);
    }

    await _db.batch((batch) {
      batch.insertAll(
        _db.products,
        [
          for (var i = 0; i < _seedProducts.length; i++)
            db.ProductsCompanion.insert(
              id: Value(_seedProducts[i].id),
              name: _seedProducts[i].name,
              priceCents: _seedProducts[i].priceCents,
              unit: Value(_seedProducts[i].unit),
              imagePath: Value(imagePaths[_seedProducts[i].id]),
              sortIndex: Value(i),
              createdAt: now,
            ),
        ],
      );
    });
  }

  /// 把内置商品图 asset 复制到应用文档目录 product_images/，返回文件路径
  Future<String> _copyBundledImage(String fileName) async {
    final data =
        await rootBundle.load('assets/images/products/$fileName');
    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'product_images'));
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }
    final file = File(p.join(imagesDir.path, 'seed_$fileName'));
    await file.writeAsBytes(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      flush: true,
    );
    return file.path;
  }

  /// 读取在售商品，按排序字段升序（收银网格用）
  Future<List<Product>> watchActive() => _getProducts(activeOnly: true);

  /// 读取全部商品（含已停用），按排序字段升序（管理页用）
  Future<List<Product>> watchAll() => _getProducts(activeOnly: false);

  Future<List<Product>> _getProducts({required bool activeOnly}) async {
    final query = _db.select(_db.products)
      ..orderBy([(t) => OrderingTerm(expression: t.sortIndex)]);
    if (activeOnly) {
      query.where((t) => t.isActive.equals(1));
    }
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  /// 商品名是否已存在（编辑时可排除自身）
  Future<bool> nameExists(String name, {int? excludeId}) async {
    final query = _db.select(_db.products)
      ..where((t) => t.name.equals(name));
    if (excludeId != null) {
      query.where((t) => t.id.equals(excludeId).not());
    }
    return (await query.get()).isNotEmpty;
  }

  /// 新增商品，放到末尾
  Future<int> add({
    required String name,
    required int priceCents,
    required String unit,
    String? imagePath,
  }) async {
    final maxSort =
        _db.products.sortIndex.max();
    final maxRow = await (_db.selectOnly(_db.products)
          ..addColumns([maxSort]))
        .getSingle();
    final nextSort = (maxRow.read(maxSort) ?? -1) + 1;

    return _db.into(_db.products).insert(
          db.ProductsCompanion.insert(
            name: name,
            priceCents: priceCents,
            unit: Value(unit),
            imagePath: Value(imagePath),
            sortIndex: Value(nextSort),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  /// 更新商品（名称 / 单价 / 单位 / 图片）
  Future<void> updateProduct({
    required int id,
    required String name,
    required int priceCents,
    required String unit,
    String? imagePath,
  }) {
    return (_db.update(_db.products)..where((t) => t.id.equals(id))).write(
      db.ProductsCompanion(
        name: Value(name),
        priceCents: Value(priceCents),
        unit: Value(unit),
        imagePath: Value(imagePath),
      ),
    );
  }

  /// 停用 / 重新启用
  Future<void> setActive(int id, bool active) {
    return (_db.update(_db.products)..where((t) => t.id.equals(id))).write(
      db.ProductsCompanion(isActive: Value(active ? 1 : 0)),
    );
  }

  /// 按给定顺序重排（products 为当前全部商品的目标顺序），仅更新排序字段
  Future<void> reorder(List<Product> products) async {
    await _db.batch((batch) {
      for (var i = 0; i < products.length; i++) {
        batch.update(
          _db.products,
          db.ProductsCompanion(sortIndex: Value(i)),
          where: (t) => t.id.equals(products[i].id),
        );
      }
    });
  }

  Product _toDomain(db.Product row) => Product(
        id: row.id,
        name: row.name,
        priceCents: row.priceCents,
        unit: row.unit,
        isActive: row.isActive == 1,
        imagePath: row.imagePath,
      );
}

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(appDatabaseProvider));
});
