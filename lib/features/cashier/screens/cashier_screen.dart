import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/providers/active_products_provider.dart';
import '../../../core/repositories/order_repository.dart';
import '../../../core/settings/keep_awake_controller.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../providers/current_order_provider.dart';
import '../providers/today_summary_provider.dart';
import '../widgets/product_card.dart';
import '../widgets/quantity_pad_sheet.dart';
import '../widgets/quick_quantity_bar.dart';

/// 收银主页：整块屏幕留给计价，低频操作收入抽屉，无底部 Tab
class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> {
  late final KeepAwakeController _keepAwake = KeepAwakeController(ref);

  @override
  void initState() {
    super.initState();
    _keepAwake.start();
  }

  @override
  void dispose() {
    _keepAwake.dispose();
    super.dispose();
  }

  Future<void> _openKeyboard() async {
    final order = ref.read(currentOrderProvider);
    final id = order.selectedProductId;
    if (id == null) return;
    final result = await QuantityPadSheet.show(
      context,
      initial: order.selectedQuantity(id).clamp(1, 1 << 30),
    );
    if (result != null) {
      ref.read(currentOrderProvider.notifier).setSelectedQuantity(result);
    }
  }

  Future<void> _checkout() async {
    final notifier = ref.read(currentOrderProvider.notifier);
    final order = ref.read(currentOrderProvider);
    if (order.isEmpty) return;

    // 先落库（单事务写 orders + 明细），成功后再清空内存订单
    final lines = order.lines;
    await ref.read(orderRepositoryProvider).checkout(lines);
    AppHaptics.medium(ref);
    notifier.clear();
    ref.invalidate(todaySummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    UiScale.init(context);
    final productsAsync = ref.watch(activeProductsProvider);
    final order = ref.watch(currentOrderProvider);
    final todayAsync = ref.watch(todaySummaryProvider);
    final notifier = ref.read(currentOrderProvider.notifier);
    final pad = UiScale.scale(12);

    const loading = Scaffold(body: Center(child: CircularProgressIndicator()));

    final products = productsAsync.value;
    if (products == null) return loading;
    final today = todayAsync.value ?? const OrderSummary();

    final selectedId = order.selectedProductId;
    final selectedName = selectedId == null
        ? null
        : products
              .firstWhere(
                (p) => p.id == selectedId,
                orElse: () => products.first,
              )
              .name;

    return Scaffold(
      drawer: const AppDrawer(),
      onDrawerChanged: (isOpened) {
        // 抽屉关闭时刷新：用户可能在设置 / 商品管理里改了商品或价格
        if (!isOpened) {
          ref.invalidate(activeProductsProvider);
          ref.invalidate(todaySummaryProvider);
        }
      },
      body: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _keepAwake.onUserInteraction(),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(pad, UiScale.scale(6), pad, pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TopBar(today: today),
                _AmountPanel(order: order),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final spacing = UiScale.scale(10);
                      final cellW =
                          (constraints.maxWidth - spacing * 2) / 3;
                      final rows = (products.length / 3).ceil();

                      double aspectRatio;
                      bool scrollable;
                      if (rows <= 2) {
                        // 一 / 两排：卡片高度精确适配可用空间，完整显示、不滚动
                        final cellH =
                            (constraints.maxHeight - (rows - 1) * spacing) /
                                rows;
                        aspectRatio = cellW / cellH;
                        scrollable = false;
                      } else {
                        // 三排及以上：固定宽高比，超出部分滚动
                        aspectRatio = 0.72;
                        scrollable = true;
                      }

                      return GridView.builder(
                        physics: scrollable
                            ? null
                            : const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: spacing,
                          crossAxisSpacing: spacing,
                          childAspectRatio: aspectRatio,
                        ),
                        itemBuilder: (context, i) {
                          final product = products[i];
                          return ProductCard(
                            product: product,
                            quantity:
                                order.selectedQuantity(product.id),
                            selected: selectedId == product.id,
                            onTap: () {
                              AppHaptics.light(ref);
                              notifier.addOne(product);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                SizedBox(height: pad),
                QuickQuantityBar(
                  hasSelection: selectedId != null,
                  selectedName: selectedName,
                  onPick: notifier.setSelectedQuantity,
                  onClear: () => notifier.setSelectedQuantity(0),
                  onOpenKeyboard: _openKeyboard,
                ),
                SizedBox(height: pad),
                _CheckoutBar(
                  enabled: !order.isEmpty,
                  onCheckout: _checkout,
                  onClearAll: notifier.clear,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶部栏：菜单按钮 + 当日流水（金额 / 订单数）
class _TopBar extends StatelessWidget {
  const _TopBar({required this.today});

  final OrderSummary today;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: UiScale.scale(40),
      child: Row(
        children: [
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => Scaffold.of(context).openDrawer(),
              child: Icon(
                Icons.menu,
                size: UiScale.scale(28),
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '今日流水 '),
                  TextSpan(
                    text: formatCents(today.totalCents),
                    style: const TextStyle(color: AppColors.selected),
                  ),
                ],
              ),
              style: TextStyle(
                fontSize: UiScale.scale(18),
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          SizedBox(width: UiScale.scale(16)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '今日 '),
                  TextSpan(
                    text: '${today.orderCount}',
                    style: const TextStyle(color: AppColors.selected),
                  ),
                  const TextSpan(text: ' 单'),
                ],
              ),
              style: TextStyle(
                fontSize: UiScale.scale(18),
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 金额面板：左侧明细行，右侧超大应收金额
class _AmountPanel extends StatelessWidget {
  const _AmountPanel({required this.order});

  final CurrentOrderState order;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: UiScale.scale(6)),
      child: Align(
        alignment: Alignment.centerRight,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            formatCents(order.totalCents),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              height: 1,
              color: AppColors.selected,
              fontSize: 56,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckoutBar extends StatefulWidget {
  const _CheckoutBar({
    required this.enabled,
    required this.onCheckout,
    required this.onClearAll,
  });

  final bool enabled;
  final VoidCallback onCheckout;
  final VoidCallback onClearAll;

  @override
  State<_CheckoutBar> createState() => _CheckoutBarState();
}

class _CheckoutBarState extends State<_CheckoutBar> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 清零在左下，描边按钮，与青色主按钮区分，不做二次确认
        OutlinedButton(
          onPressed: widget.enabled ? widget.onClearAll : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            padding: EdgeInsets.symmetric(
              horizontal: UiScale.scale(22),
              vertical: UiScale.scale(12),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(UiScale.scale(14)),
            ),
          ),
          child: Text(
            '清零',
            style: TextStyle(
              fontSize: UiScale.scale(19),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(width: UiScale.scale(12)),
        Expanded(
          child: GestureDetector(
            onTapDown: widget.enabled
                ? (_) => setState(() => _pressed = true)
                : null,
            onTapUp: widget.enabled
                ? (_) => setState(() => _pressed = false)
                : null,
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.enabled ? widget.onCheckout : null,
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1,
              duration: const Duration(milliseconds: 90),
              child: Container(
                height: UiScale.snap(UiScale.scale(52)),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.enabled ? AppColors.selected : AppColors.button,
                  borderRadius: BorderRadius.circular(
                    UiScale.snap(UiScale.scale(16)),
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '结账下一位',
                    style: TextStyle(
                      fontSize: UiScale.scale(22),
                      fontWeight: FontWeight.w800,
                      color: widget.enabled
                          ? Colors.white
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
