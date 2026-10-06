import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/repositories/cost_repository.dart';
import '../providers/cost_providers.dart';

/// 类目管理：新增 / 改名 / 软删除
class CategoryManageScreen extends ConsumerWidget {
  const CategoryManageScreen({super.key});

  Future<String?> _askName(
    BuildContext context, {
    required String title,
    String? initial,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(title: title, initial: initial),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = await _askName(context, title: '新建类目');
    if (name == null) return;
    final repo = ref.read(costRepositoryProvider);
    if (await repo.nameExists(name)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该类目已存在')),
        );
      }
      return;
    }
    await repo.addCategory(name);
    ref.invalidate(allCostCategoriesProvider);
    ref.invalidate(activeCostCategoriesProvider);
  }

  Future<void> _rename(
      BuildContext context, WidgetRef ref, CostCategory category) async {
    final name = await _askName(
      context,
      title: '类目改名',
      initial: category.name,
    );
    if (name == null || name == category.name) return;
    final repo = ref.read(costRepositoryProvider);
    if (await repo.nameExists(name, excludeId: category.id)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该类目已存在')),
        );
      }
      return;
    }
    await repo.renameCategory(category.id, name);
    ref.invalidate(allCostCategoriesProvider);
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, CostCategory category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除该类目？'),
        content: Text(
          '「${category.name}」将从新建时的选择列表隐藏，'
          '但历史采购记录仍保留并照常计入汇总，此操作不可恢复。',
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

    await ref.read(costRepositoryProvider).deactivateCategory(category.id);
    ref.invalidate(allCostCategoriesProvider);
    ref.invalidate(activeCostCategoriesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    UiScale.init(context);
    final categories = ref.watch(allCostCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('类目管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('新建类目'),
      ),
      body: SafeArea(
        child: categories.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('读取失败：$e')),
          data: (list) {
            if (list.isEmpty) {
              return Center(
                child: Text(
                  '暂无类目，点击下方按钮新建',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              );
            }
            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                UiScale.scale(12),
                UiScale.scale(12),
                UiScale.scale(12),
                // FAB 高 56 + 下边距 16 不随 UiScale 缩放，底部预留固定值避免遮挡末行
                88,
              ),
              itemCount: list.length,
              separatorBuilder: (_, _) =>
                  SizedBox(height: UiScale.scale(8)),
              itemBuilder: (context, i) {
                final category = list[i];
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(UiScale.scale(14)),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListTile(
                    title: Text(
                      category.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: category.isActive
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                        decoration: category.isActive
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: category.isActive
                        ? null
                        : const Text('已停用（历史记录保留）'),
                    trailing: category.isActive
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: '改名',
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () =>
                                    _rename(context, ref, category),
                              ),
                              IconButton(
                                tooltip: '删除',
                                icon: const Icon(Icons.delete_outline),
                                color: AppColors.danger,
                                onPressed: () =>
                                    _delete(context, ref, category),
                              ),
                            ],
                          )
                        : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// 输入类目名称的对话框。controller 随本组件销毁而释放，
/// 避免弹窗关闭动画期间访问已 dispose 的 controller
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    Navigator.of(context).pop(text.isEmpty ? null : text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _submit,
          child: const Text('确定'),
        ),
      ],
    );
  }
}
