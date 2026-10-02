import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/order_line.dart';
import '../../../shared/models/product.dart';

/// 当前订单状态：已点商品行 + 当前选中商品 id
class CurrentOrderState {
  const CurrentOrderState({
    this.lines = const [],
    this.selectedProductId,
  });

  final List<OrderLine> lines;
  final int? selectedProductId;

  int get totalCents =>
      lines.fold(0, (sum, line) => sum + line.lineTotalCents);

  bool get isEmpty => lines.isEmpty;

  /// 当前选中商品的数量（未点则为 0）
  int selectedQuantity(int productId) {
    for (final line in lines) {
      if (line.product.id == productId) return line.quantity;
    }
    return 0;
  }

  CurrentOrderState copyWith({
    List<OrderLine>? lines,
    int? selectedProductId,
    bool clearSelection = false,
  }) {
    return CurrentOrderState(
      lines: lines ?? this.lines,
      selectedProductId:
          clearSelection ? null : (selectedProductId ?? this.selectedProductId),
    );
  }
}

class CurrentOrderNotifier extends Notifier<CurrentOrderState> {
  @override
  CurrentOrderState build() => const CurrentOrderState();

  /// 点按商品卡片：数量 +1，并选中该商品
  void addOne(Product product) {
    state = state.copyWith(
      lines: _updateQuantity(product, state.selectedQuantity(product.id) + 1),
      selectedProductId: product.id,
    );
  }

  /// 快捷数量：把选中商品数量直接设为 n（语义为「设为 N」）；
  /// n <= 0（清除）时移除商品并取消选中，边框还原为未选中样式
  void setSelectedQuantity(int n) {
    final id = state.selectedProductId;
    if (id == null) return;
    final product = _findProduct(id);
    if (product == null) return;
    if (n <= 0) {
      state = state.copyWith(
        lines: _updateQuantity(product, 0),
        clearSelection: true,
      );
    } else {
      state = state.copyWith(lines: _updateQuantity(product, n));
    }
  }

  /// 清空当前订单（不记账）
  void clear() {
    state = const CurrentOrderState();
  }

  /// 卡片底部「清除」：直接移除该商品（选中态保留，便于继续操作）
  void removeProduct(int productId) {
    final lines =
        state.lines.where((l) => l.product.id != productId).toList();
    state = state.copyWith(lines: lines);
  }

  Product? _findProduct(int id) {
    for (final line in state.lines) {
      if (line.product.id == id) return line.product;
    }
    return null;
  }

  /// n <= 0 时移除该商品行
  List<OrderLine> _updateQuantity(Product product, int n) {
    final lines = [...state.lines];
    final index = lines.indexWhere((l) => l.product.id == product.id);
    if (index >= 0) {
      if (n <= 0) {
        lines.removeAt(index);
      } else {
        lines[index] = OrderLine(product: product, quantity: n);
      }
    } else if (n > 0) {
      lines.add(OrderLine(product: product, quantity: n));
    }
    return lines;
  }
}

final currentOrderProvider =
    NotifierProvider<CurrentOrderNotifier, CurrentOrderState>(
  CurrentOrderNotifier.new,
);
