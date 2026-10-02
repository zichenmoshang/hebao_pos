import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/repositories/cost_repository.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/utils/money.dart';
import '../providers/cost_providers.dart';
import '../widgets/cost_filter_bar.dart';
import '../widgets/cost_record_form.dart';
import 'category_manage_screen.dart';

/// 成本记录页：时间筛选 + 区间采购总额 + 采购流水
class CostScreen extends ConsumerStatefulWidget {
  const CostScreen({super.key});

  @override
  ConsumerState<CostScreen> createState() => _CostScreenState();
}

class _CostScreenState extends ConsumerState<CostScreen> {
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('zh_CN');
  }

  Future<void> _openForm({CostRecord? existing}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UiScale.scale(18)),
        ),
      ),
      builder: (_) => CostRecordForm(existing: existing),
    );
    if (changed == true) _invalidate();
  }

  Future<void> _confirmDelete(CostRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除该笔采购？'),
        content: Text(
          '将删除 ${DateFormat('M月d日', 'zh_CN').format(record.occurredOn)} '
          '${record.categoryName} ${formatCents(record.amountCents)}，'
          '区间总额将自动重算，此操作不可恢复。',
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

    await ref.read(costRepositoryProvider).deleteRecord(record.id);
    AppHaptics.medium(ref);
    _invalidate();
  }

  void _invalidate() {
    ref.invalidate(costTotalProvider);
    ref.invalidate(costRecordsProvider);
    ref.invalidate(activeCostCategoriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    UiScale.init(context);
    final total = ref.watch(costTotalProvider);
    final records = ref.watch(costRecordsProvider);
    final pad = UiScale.scale(12);

    return Scaffold(
      appBar: AppBar(
        title: const Text('成本记录'),
        actions: [
          IconButton(
            tooltip: '类目管理',
            icon: const Icon(Icons.category_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CategoryManageScreen(),
                ),
              );
              _invalidate();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('记一笔'),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(pad),
          children: [
            const CostFilterBar(),
            SizedBox(height: pad),
            total.when(
              loading: () => const SizedBox(
                height: 96,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('读取失败：$e'),
              data: (cents) => _TotalCard(amountCents: cents),
            ),
            SizedBox(height: pad),
            records.when(
              loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('读取失败：$e'),
              data: (list) {
                if (list.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: UiScale.scale(40)),
                    child: Center(
                      child: Text(
                        '该区间暂无采购记录',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: UiScale.scale(15),
                        ),
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final record in list)
                      Padding(
                        padding: EdgeInsets.only(bottom: UiScale.scale(8)),
                        child: Dismissible(
                          key: ValueKey(record.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.only(
                                right: UiScale.scale(20)),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(
                                  UiScale.scale(14)),
                            ),
                            child: const Icon(Icons.delete_outline,
                                color: Colors.white),
                          ),
                          confirmDismiss: (_) async {
                            await _confirmDelete(record);
                            return false;
                          },
                          child: _RecordCard(
                            record: record,
                            onTap: () => _openForm(existing: record),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            SizedBox(height: UiScale.scale(72)),
          ],
        ),
      ),
    );
  }
}

/// 区间采购总额卡片
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.amountCents});

  final int amountCents;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: UiScale.scale(16),
        vertical: UiScale.scale(18),
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(UiScale.scale(14)),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: AppColors.selected),
          SizedBox(width: UiScale.scale(12)),
          Expanded(
            child: Text(
              '区间采购总额',
              style: TextStyle(
                fontSize: UiScale.scale(15),
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            formatCents(amountCents),
            style: TextStyle(
              fontSize: UiScale.scale(24),
              fontWeight: FontWeight.w800,
              color: AppColors.selected,
            ),
          ),
        ],
      ),
    );
  }
}

/// 单条采购卡片
class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.record, required this.onTap});

  final CostRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: UiScale.scale(14),
          vertical: UiScale.scale(14),
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(UiScale.scale(14)),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.categoryName,
                    style: TextStyle(
                      fontSize: UiScale.scale(16),
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: UiScale.scale(3)),
                  Text(
                    DateFormat('yyyy年M月d日', 'zh_CN')
                        .format(record.occurredOn),
                    style: TextStyle(
                      fontSize: UiScale.scale(13),
                      color: AppColors.textMuted,
                    ),
                  ),
                  if ((record.note ?? '').isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: UiScale.scale(3)),
                      child: Text(
                        record.note!,
                        style: TextStyle(
                          fontSize: UiScale.scale(13),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Text(
              formatCents(record.amountCents),
              style: TextStyle(
                fontSize: UiScale.scale(18),
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
