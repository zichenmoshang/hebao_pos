import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart' as db;
import '../database/app_database_provider.dart';
import '../../shared/models/product.dart';

/// 固定 5 个品类的种子数据（id 与原硬编码保持一致）
const _seedProducts = [
  Product(id: 1, name: '肉锅贴', priceCents: 80),
  Product(id: 2, name: '素锅贴', priceCents: 70),
  Product(id: 3, name: '豆浆', priceCents: 200, unit: '杯'),
  Product(id: 4, name: '豆腐脑', priceCents: 300, unit: '碗'),
  Product(id: 5, name: '五香蛋', priceCents: 150),
];

class ProductRepository {
  ProductRepository(this._db);

  final db.AppDatabase _db;

  /// 首次启动时写入 5 个商品；已有数据则跳过
  Future<void> ensureSeeded() async {
    final count = await _db.products.count().getSingle();
    if (count > 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
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
              sortIndex: Value(i),
              createdAt: now,
            ),
        ],
      );
    });
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
