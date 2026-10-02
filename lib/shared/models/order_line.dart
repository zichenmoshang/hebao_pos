import 'product.dart';

/// 当前订单中的一行：商品 + 数量（未结账，仅存内存）
class OrderLine {
  const OrderLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  int get lineTotalCents => product.priceCents * quantity;
}
