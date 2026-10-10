import 'product.dart';

/// 堂食 / 打包
enum OrderChannel {
  dineIn,
  takeout;

  /// 数据库存储值
  String get dbValue => switch (this) {
        OrderChannel.dineIn => 'dine_in',
        OrderChannel.takeout => 'takeout',
      };

  static OrderChannel fromDb(String value) =>
      value == 'takeout' ? OrderChannel.takeout : OrderChannel.dineIn;
}

/// 当前订单中的一行：商品 + 数量 + 堂食/打包（未结账，仅存内存）
class OrderLine {
  const OrderLine({
    required this.product,
    required this.quantity,
    this.channel = OrderChannel.dineIn,
  });

  final Product product;
  final int quantity;
  final OrderChannel channel;

  int get lineTotalCents => product.priceCents * quantity;
}
