import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/features/cashier/providers/current_order_provider.dart';
import 'package:hebao_pos/shared/models/order_line.dart';
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

  test('clear 重置全部', () {
    final notifier = container.read(currentOrderProvider.notifier);
    notifier.addOne(p1);
    notifier.clear();
    expect(container.read(currentOrderProvider).lines, isEmpty);
  });

  test('addOne 不同商品各占一行，选中态跟随最新点按', () {
    final notifier = container.read(currentOrderProvider.notifier);

    notifier.addOne(p1);
    notifier.addOne(p3);

    final state = container.read(currentOrderProvider);
    expect(state.lines, hasLength(2));
    expect(state.lines.map((e) => e.product.id), [1, 3]);
    expect(state.selectedProductId, 3);
    expect(state.totalCents, 280);
  });

  test('totalCents 跨多行累计，isEmpty 反映是否为空单', () {
    final notifier = container.read(currentOrderProvider.notifier);
    expect(container.read(currentOrderProvider).isEmpty, isTrue);
    expect(container.read(currentOrderProvider).totalCents, 0);

    notifier.addOne(p1);
    notifier.addOne(p1);
    notifier.addOne(p3);

    final state = container.read(currentOrderProvider);
    expect(state.isEmpty, isFalse);
    expect(state.totalCents, 360);
  });

  test('quantityOf 返回对应商品各通道数量，未点商品为 0', () {
    final notifier = container.read(currentOrderProvider.notifier);
    notifier.addOne(p1);
    notifier.addOne(p1);

    final state = container.read(currentOrderProvider);
    expect(state.quantityOf(1, OrderChannel.dineIn), 2);
    expect(state.quantityOf(1, OrderChannel.takeout), 0);
    expect(state.quantityOf(3, OrderChannel.dineIn), 0);
  });

  test('setSelectedQuantity 负数与 0 一样移除并取消选中', () {
    final notifier = container.read(currentOrderProvider.notifier);
    notifier.addOne(p1);

    notifier.setSelectedQuantity(-3);

    final state = container.read(currentOrderProvider);
    expect(state.lines, isEmpty);
    expect(state.selectedProductId, isNull);
  });

  group('堂食 / 打包通道', () {
    test('默认堂食；切到打包后 addOne 与快捷数字落在打包行', () {
      final notifier = container.read(currentOrderProvider.notifier);

      notifier.addOne(p1);
      notifier.addOne(p1);
      notifier.setChannel(OrderChannel.takeout);
      notifier.addOne(p1);
      notifier.setSelectedQuantity(4);

      final state = container.read(currentOrderProvider);
      expect(state.lines, hasLength(2));
      expect(state.dineQuantityOf(1), 2);
      expect(state.takeQuantityOf(1), 4);
      // 两行都计入总额
      expect(state.totalCents, 480);
    });

    test('清除当前通道只移除该行，另一通道保留且不取消选中', () {
      final notifier = container.read(currentOrderProvider.notifier);

      notifier.addOne(p1);
      notifier.setChannel(OrderChannel.takeout);
      notifier.addOne(p1);
      notifier.setSelectedQuantity(0);

      final state = container.read(currentOrderProvider);
      expect(state.takeQuantityOf(1), 0);
      expect(state.dineQuantityOf(1), 1);
      expect(state.selectedProductId, 1);
    });

    test('selectedQuantity 跟随当前通道；clear 后通道复位为堂食', () {
      final notifier = container.read(currentOrderProvider.notifier);

      notifier.addOne(p1);
      notifier.setChannel(OrderChannel.takeout);
      notifier.addOne(p1);
      notifier.addOne(p1);

      expect(container.read(currentOrderProvider).selectedQuantity, 2);

      notifier.setChannel(OrderChannel.dineIn);
      expect(container.read(currentOrderProvider).selectedQuantity, 1);

      notifier.clear();
      final state = container.read(currentOrderProvider);
      expect(state.selectedChannel, OrderChannel.dineIn);
      expect(state.lines, isEmpty);
    });
  });
}
