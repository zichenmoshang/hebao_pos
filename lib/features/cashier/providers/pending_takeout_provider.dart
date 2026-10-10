import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/repositories/order_repository.dart';

/// 待打包清单：未交付的打包明细（按下单时间升序）。
/// 结账、交付、撤销、删单后由调用方 invalidate 刷新
final pendingTakeoutProvider = FutureProvider<List<TakeoutItem>>((ref) async {
  return ref.watch(orderRepositoryProvider).pendingTakeoutItems();
});

/// 最近已交付的打包明细（清单内「撤销」用，按交付时间倒序）
final deliveredTakeoutProvider = FutureProvider<List<TakeoutItem>>((ref) async {
  return ref.watch(orderRepositoryProvider).deliveredTakeoutItems();
});
