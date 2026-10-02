import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/repositories/order_repository.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../providers/stats_providers.dart';

/// 区间订单明细：列出当前筛选区间内的订单，可滑动删除错单
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, OrderRecord order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除该订单？'),
        content: Text(
          '将删除 ${DateFormat('M月d日 HH:mm').format(order.createdAt)} '
          '金额为 ${formatCents(order.totalCents)} 的订单及其明细，'
          '统计将自动重算，此操作不可恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(orderRepositoryProvider).deleteOrder(order.id);
    AppHaptics.medium(ref);
    ref.invalidate(statsOrdersProvider);
    ref.invalidate(statsSummaryProvider);
    ref.invalidate(statsDailyRevenueProvider);
    ref.invalidate(statsProductSalesProvider);
    ref.invalidate(statsDailyProductQuantityProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    UiScale.init(context);
    final orders = ref.watch(statsOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('区间订单明细')),
      body: SafeArea(
        child: orders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('读取失败：$e')),
          data: (list) {
            if (list.isEmpty) {
              return Center(
                child: Text(
                  '该区间暂无订单',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: UiScale.scale(15),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: EdgeInsets.all(UiScale.scale(12)),
              itemCount: list.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: UiScale.scale(8)),
              itemBuilder: (context, i) {
                final order = list[i];
                return Dismissible(
                  key: ValueKey(order.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: UiScale.scale(20)),
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      borderRadius:
                          BorderRadius.circular(UiScale.scale(14)),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.white),
                  ),
                  confirmDismiss: (_) async {
                    await _confirmDelete(context, ref, order);
                    return false; // 删除由确认弹窗处理，列表不自动移除
                  },
                  child: _OrderCard(order: order),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends ConsumerWidget {
  const _OrderCard({required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(UiScale.scale(14)),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context)
            .copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: UiScale.scale(14),
          ),
          title: Text(
            DateFormat('M月d日 HH:mm').format(order.createdAt),
            style: TextStyle(
              fontSize: UiScale.scale(15),
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          trailing: Text(
            formatCents(order.totalCents),
            style: TextStyle(
              fontSize: UiScale.scale(17),
              fontWeight: FontWeight.w800,
              color: AppColors.selected,
            ),
          ),
          children: [
            ref.watch(orderItemsProvider(order.id)).when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('读取失败：$e'),
                  ),
                  data: (items) => Padding(
                    padding: EdgeInsets.fromLTRB(
                      UiScale.scale(14),
                      0,
                      UiScale.scale(14),
                      UiScale.scale(12),
                    ),
                    child: Column(
                      children: [
                        for (final it in items)
                          Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: UiScale.scale(3)),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${it.name} × ${it.quantity}',
                                  style: TextStyle(
                                    fontSize: UiScale.scale(14),
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(
                                  formatCents(it.amountCents),
                                  style: TextStyle(
                                    fontSize: UiScale.scale(14),
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
