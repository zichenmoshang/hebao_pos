import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/features/cashier/providers/current_order_provider.dart';
import 'package:hebao_pos/shared/models/product.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  const p1 = Product(id: 1, name: '肉锅贴', priceCents: 80);
  const p3 = Product(id: 3, name: '豆浆', priceCents: 200);

  test('addOne 累加数量并选中该商品', () {
    final notifier = container.read(currentOrderProvider.notifier);

    notifier.addOne(p1);
    notifier.addOne(p1);

    final state = container.read(currentOrderProvider);
    expect(state.lines.single.quantity, 2);
    expect(state.selectedProductId, 1);
    expect(state.totalCents, 160);
  });

  test('setSelectedQuantity 直接替换数量', () {
    final notifier = container.read(currentOrderProvider.notifier);

    notifier.addOne(p1);
    notifier.setSelectedQuantity(9);
    expect(container.read(currentOrderProvider).lines.single.quantity, 9);

    // 设为 0 移除商品并取消选中
    notifier.setSelectedQuantity(0);
    final state = container.read(currentOrderProvider);
    expect(state.lines, isEmpty);
    expect(state.selectedProductId, isNull);
  });

  test('未选中商品时 setSelectedQuantity 无效果', () {
    container.read(currentOrderProvider.notifier).setSelectedQuantity(5);
    expect(container.read(currentOrderProvider).lines, isEmpty);
  });

  test('removeProduct 移除指定行并保留选中态', () {
    final notifier = container.read(currentOrderProvider.notifier);
    notifier.addOne(p1);
    notifier.addOne(p3);

    notifier.removeProduct(1);

    final state = container.read(currentOrderProvider);
    expect(state.lines.single.product.id, 3);
    expect(state.selectedProductId, 3);
  });

  test('clear 重置全部', () {
    final notifier = container.read(currentOrderProvider.notifier);
    notifier.addOne(p1);
    notifier.clear();
    expect(container.read(currentOrderProvider).lines, isEmpty);
  });
}
