import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/shared/models/order_line.dart';
import 'package:hebao_pos/shared/models/product.dart';

void main() {
  test('lineTotalCents 为单价乘数量', () {
    const line = OrderLine(
      product: Product(id: 1, name: '肉锅贴', priceCents: 80),
      quantity: 3,
    );
    expect(line.lineTotalCents, 240);
  });

  test('数量为 0 时小计为 0', () {
    const line = OrderLine(
      product: Product(id: 1, name: '肉锅贴', priceCents: 80),
      quantity: 0,
    );
    expect(line.lineTotalCents, 0);
  });
}
