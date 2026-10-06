import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/providers/active_products_provider.dart';
import '../../../core/repositories/order_repository.dart';
import '../../../core/settings/keep_awake_controller.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../../../shared/widgets/app_drawer.dart';
import '../../stats/providers/stats_providers.dart';
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

  /// 结账提交中标志：仅为了拦住 await 窗口内的快速连点，防重复落库
  bool _isCheckoutInFlight = false;

  /// 提交是否已超时：超时只释放锁、保留当前订单，避免按钮永久不可用
  bool _checkoutTimedOut = false;

  Timer? _checkoutTimeoutTimer;

  /// 本地事务正常在几十毫秒内完成，500ms 超时仅作兜底，防锁永久不释放
  static const _checkoutTimeout = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _keepAwake.start();
  }

  @override
  void dispose() {
    _checkoutTimeoutTimer?.cancel();
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
    // 快速连点防护：上一笔尚未落库完成时直接忽略后续点击
    if (_isCheckoutInFlight) return;

    final order = ref.read(currentOrderProvider);
    if (order.isEmpty) return;

    final notifier = ref.read(currentOrderProvider.notifier);
    final lines = order.lines;

    setState(() {
      _isCheckoutInFlight = true;
      _checkoutTimedOut = false;
    });
    // 超时兜底：即便底层异常卡死也强制释放锁，按钮不会永久不可用
    _checkoutTimeoutTimer = Timer(_checkoutTimeout, () {
      if (mounted) {
        setState(() {
          _isCheckoutInFlight = false;
          _checkoutTimedOut = true;
        });
      }
    });

    try {
      // 先落库（单事务写 orders + 明细），成功后再清空内存订单
      await ref.read(orderRepositoryProvider).checkout(lines);
      _checkoutTimeoutTimer?.cancel();

      // 落库成功必须清零并刷新统计，即便已超过兜底超时：
      // 慢设备上写库可能超过 500ms，此时锁已释放，若不清零，
      // 界面重显旧金额，用户再点「结账」会重复落库同一笔
      AppHaptics.medium(ref);
      notifier.clear();
      if (mounted) {
        ref.invalidate(todaySummaryProvider);
        // 统计页 provider 无监听时仍缓存，结账后重进统计页应看到新数据
        ref.invalidate(statsSummaryProvider);
        ref.invalidate(statsDailyRevenueProvider);
        ref.invalidate(statsProductSalesProvider);
      }
    } catch (_) {
      // 失败不弹提示：静默清掉这一单，保证快速计价流程不被阻塞
      _checkoutTimeoutTimer?.cancel();
      if (_checkoutTimedOut) return;
      notifier.clear();
    } finally {
      if (mounted && !_checkoutTimedOut) {
        setState(() => _isCheckoutInFlight = false);
      }
    }
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
    // 选中商品已从在售列表消失（停用）时不再回退到首个商品，返回 null
    final selectedName = selectedId == null
        ? null
        : products
              .where((p) => p.id == selectedId)
              .firstOrNull
              ?.name;

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
                  child: products.isEmpty
                      ? const _EmptyProductsView()
                      : LayoutBuilder(
                    builder: (context, constraints) {
                      final spacing = UiScale.scale(10);
                      final cellW =
                          (constraints.maxWidth - spacing * 2) / 3;
                      final rows = (products.length / 3).ceil();

                      double aspectRatio;
                      bool scrollable;
                      if (rows <= 3) {
                        // 三排及以内：卡片高度精确适配可用空间，完整显示、不滚动
                        final cellH =
                            (constraints.maxHeight - (rows - 1) * spacing) /
                                rows;
                        aspectRatio = cellW / cellH;
                        scrollable = false;
                      } else {
                        // 四排及以上：固定宽高比，超出部分滚动
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
                  hasSelection: selectedName != null,
                  selectedName: selectedName,
                  onPick: notifier.setSelectedQuantity,
                  onClear: () => notifier.setSelectedQuantity(0),
                  onOpenKeyboard: _openKeyboard,
                ),
                SizedBox(height: pad),
                _CheckoutBar(
                  enabled: !order.isEmpty && !_isCheckoutInFlight,
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

/// 全部商品停用 / 无在售商品时的空态，避免空网格除零与崩溃
class _EmptyProductsView extends StatelessWidget {
  const _EmptyProductsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inventory_2_outlined,
              color: AppColors.textMuted, size: 48),
          SizedBox(height: UiScale.scale(12)),
          Text(
            '暂无在售商品',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: UiScale.scale(15),
            ),
          ),
          SizedBox(height: UiScale.scale(6)),
          Text(
            '可在抽屉 → 设置 → 商品管理中新增或启用',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: UiScale.scale(13),
            ),
          ),
        ],
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
