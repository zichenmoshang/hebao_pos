import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/repositories/order_repository.dart';
import '../../../core/utils/haptics.dart';
import '../providers/pending_takeout_provider.dart';

/// 待打包清单：半屏弹层。
/// 待交付条目点一下即「已交付」（震动反馈）；刚交付的条目可点「撤销」回到待打包
class PendingTakeoutSheet extends ConsumerWidget {
  const PendingTakeoutSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(UiScale.scale(24))),
      ),
      builder: (_) => const PendingTakeoutSheet(),
    );
  }

  Future<void> _deliver(WidgetRef ref, TakeoutItem item) async {
    await ref.read(orderRepositoryProvider).markTakeoutDelivered(item.itemId);
    AppHaptics.light(ref);
    _refresh(ref);
  }

  Future<void> _undo(WidgetRef ref, TakeoutItem item) async {
    await ref
        .read(orderRepositoryProvider)
        .markTakeoutUndelivered(item.itemId);
    AppHaptics.light(ref);
    _refresh(ref);
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(pendingTakeoutProvider);
    ref.invalidate(deliveredTakeoutProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingTakeoutProvider);
    final deliveredAsync = ref.watch(deliveredTakeoutProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(UiScale.scale(999)),
                ),
              ),
            ),
            SizedBox(height: UiScale.scale(12)),
            Text(
              '待打包',
              style: TextStyle(
                fontSize: UiScale.scale(20),
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: UiScale.scale(8)),
            Flexible(
              child: pendingAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('读取失败：$e'),
                ),
                data: (items) {
                  final delivered =
                      deliveredAsync.value ?? const <TakeoutItem>[];
                  if (items.isEmpty && delivered.isEmpty) {
                    return Padding(
                      padding:
                          EdgeInsets.symmetric(vertical: UiScale.scale(24)),
                      child: Center(
                        child: Text(
                          '暂无待打包',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: UiScale.scale(16),
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      if (items.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: UiScale.scale(8)),
                          child: Text(
                            '都交付完啦',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: UiScale.scale(15),
                            ),
                          ),
                        )
                      else
                        for (final item in items)
                          _PendingRow(
                            item: item,
                            onTap: () => _deliver(ref, item),
                          ),
                      if (delivered.isNotEmpty) ...[
                        SizedBox(height: UiScale.scale(12)),
                        Text(
                          '已交付（点撤销可恢复）',
                          style: TextStyle(
                            fontSize: UiScale.scale(14),
                            color: AppColors.textMuted,
                          ),
                        ),
                        SizedBox(height: UiScale.scale(4)),
                        for (final item in delivered)
                          _DeliveredRow(
                            item: item,
                            onUndo: () => _undo(ref, item),
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 待交付行：整块为点击区，点一下即交付
class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.item, required this.onTap});

  final TakeoutItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: UiScale.scale(4)),
      child: Material(
        color: AppColors.button,
        borderRadius: BorderRadius.circular(UiScale.scale(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(UiScale.scale(12)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: UiScale.scale(14),
              vertical: UiScale.scale(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${item.productName} × ${item.quantity}',
                    style: TextStyle(
                      fontSize: UiScale.scale(18),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${DateFormat('HH:mm').format(item.orderCreatedAt)} 下单',
                  style: TextStyle(
                    fontSize: UiScale.scale(14),
                    color: AppColors.textMuted,
                  ),
                ),
                SizedBox(width: UiScale.scale(10)),
                Icon(Icons.check_circle_outline,
                    size: UiScale.scale(24), color: AppColors.selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 已交付行：弱化显示，尾部「撤销」按钮恢复为待打包
class _DeliveredRow extends StatelessWidget {
  const _DeliveredRow({required this.item, required this.onUndo});

  final TakeoutItem item;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: UiScale.scale(3)),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${item.productName} × ${item.quantity}',
              style: TextStyle(
                fontSize: UiScale.scale(15),
                color: AppColors.textMuted,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
          TextButton(
            onPressed: onUndo,
            style: TextButton.styleFrom(
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: EdgeInsets.symmetric(
                horizontal: UiScale.scale(10),
                vertical: UiScale.scale(6),
              ),
            ),
            child: Text(
              '撤销',
              style: TextStyle(
                fontSize: UiScale.scale(15),
                color: AppColors.selected,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
