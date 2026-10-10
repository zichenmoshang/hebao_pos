import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/order_line.dart';
import '../../../shared/models/product.dart';

/// 当前订单状态：已点商品行（按商品 + 堂食/打包分行）+ 当前选中商品与通道
class CurrentOrderState {
  const CurrentOrderState({
    this.lines = const [],
    this.selectedProductId,
    this.selectedChannel = OrderChannel.dineIn,
  });

  final List<OrderLine> lines;
  final int? selectedProductId;

  /// 快捷数量区当前作用的通道：点卡片 +1 与快捷数字都落在该通道上
  final OrderChannel selectedChannel;

  int get totalCents =>
      lines.fold(0, (sum, line) => sum + line.lineTotalCents);

  bool get isEmpty => lines.isEmpty;

  /// 某商品在指定通道的数量（未点则为 0）
  int quantityOf(int productId, OrderChannel channel) {
    for (final line in lines) {
      if (line.product.id == productId && line.channel == channel) {
        return line.quantity;
      }
    }
    return 0;
  }

  /// 某商品堂食数量
  int dineQuantityOf(int productId) => quantityOf(productId, OrderChannel.dineIn);

  /// 某商品打包数量
  int takeQuantityOf(int productId) =>
      quantityOf(productId, OrderChannel.takeout);

  /// 当前选中商品在当前通道的数量（未点则为 0）
  int get selectedQuantity {
    final id = selectedProductId;
    if (id == null) return 0;
    return quantityOf(id, selectedChannel);
  }

  CurrentOrderState copyWith({
    List<OrderLine>? lines,
    int? selectedProductId,
    OrderChannel? selectedChannel,
    bool clearSelection = false,
  }) {
    return CurrentOrderState(
      lines: lines ?? this.lines,
      selectedProductId:
          clearSelection ? null : (selectedProductId ?? this.selectedProductId),
      selectedChannel: selectedChannel ?? this.selectedChannel,
    );
  }
}

class CurrentOrderNotifier extends Notifier<CurrentOrderState> {
  @override
  CurrentOrderState build() => const CurrentOrderState();

  /// 点按商品卡片：当前通道数量 +1，并选中该商品
  void addOne(Product product) {
    final channel = state.selectedChannel;
    state = state.copyWith(
      lines: _updateQuantity(
          product, channel, state.quantityOf(product.id, channel) + 1),
      selectedProductId: product.id,
    );
  }

  /// 切换快捷数量区作用的通道（堂食 / 打包）
  void setChannel(OrderChannel channel) {
    if (channel == state.selectedChannel) return;
    state = state.copyWith(selectedChannel: channel);
  }

  /// 快捷数量：把选中商品在当前通道的数量直接设为 n（语义为「设为 N」）；
  /// n <= 0（清除）时移除该行；该商品全部通道都清零时取消选中，
  /// 边框还原为未选中样式
  void setSelectedQuantity(int n) {
    final id = state.selectedProductId;
    if (id == null) return;
    final product = _findProduct(id);
    if (product == null) return;
    final channel = state.selectedChannel;
    final lines = _updateQuantity(product, channel, n);
    final hasAny = lines.any((l) => l.product.id == id);
    state = state.copyWith(lines: lines, clearSelection: !hasAny);
  }

  /// 清空当前订单（不记账）
  void clear() {
    state = const CurrentOrderState();
  }

  Product? _findProduct(int id) {
    for (final line in state.lines) {
      if (line.product.id == id) return line.product;
    }
    return null;
  }

  /// n <= 0 时移除该商品在指定通道的行
  List<OrderLine> _updateQuantity(
      Product product, OrderChannel channel, int n) {
    final lines = [...state.lines];
    final index = lines.indexWhere(
        (l) => l.product.id == product.id && l.channel == channel);
    if (index >= 0) {
      if (n <= 0) {
        lines.removeAt(index);
      } else {
        lines[index] =
            OrderLine(product: product, quantity: n, channel: channel);
      }
    } else if (n > 0) {
      lines.add(OrderLine(product: product, quantity: n, channel: channel));
    }
    return lines;
  }
}

final currentOrderProvider =
    NotifierProvider<CurrentOrderNotifier, CurrentOrderState>(
  CurrentOrderNotifier.new,
);
