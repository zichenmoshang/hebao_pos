import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/product_repository.dart';
import '../../shared/models/product.dart';

/// 在售商品：首次访问确保种子数据写入，再从数据库读取（收银网格用）
final activeProductsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  await repo.ensureSeeded();
  return repo.watchActive();
});
