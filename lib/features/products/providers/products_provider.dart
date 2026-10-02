import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/product_repository.dart';
import '../../../shared/models/product.dart';

/// 全部商品（含已停用），商品管理页使用
final allProductsProvider = FutureProvider<List<Product>>((ref) {
  return ref.watch(productRepositoryProvider).watchAll();
});
