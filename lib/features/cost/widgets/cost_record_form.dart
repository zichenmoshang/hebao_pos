import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/repositories/cost_repository.dart';
import '../../../core/utils/haptics.dart';
import '../../../shared/widgets/app_date_picker_dialog.dart';
import '../providers/cost_providers.dart';

/// 新增 / 编辑一笔采购的底部弹层
class CostRecordForm extends ConsumerStatefulWidget {
  const CostRecordForm({super.key, this.existing});

  /// 传入则为编辑模式
  final CostRecord? existing;

  @override
  ConsumerState<CostRecordForm> createState() => _CostRecordFormState();
}

class _CostRecordFormState extends ConsumerState<CostRecordForm> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  int? _categoryId;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      final yuan = e.amountCents / 100;
      _amountCtrl.text = e.amountCents % 100 == 0
          ? yuan.toInt().toString()
          : yuan.toString();
      _noteCtrl.text = e.note ?? '';
      _date = e.occurredOn;
      _categoryId = e.categoryId;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  int? get _amountCents {
    final yuan = double.tryParse(_amountCtrl.text.trim());
    if (yuan == null || yuan <= 0) return null;
    return (yuan * 100).round();
  }

  Future<void> _pickCategory() async {
    final categories = await ref
        .read(costRepositoryProvider)
        .activeCategories();
    if (!mounted) return;

    final selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UiScale.scale(18)),
        ),
      ),
      builder: (context) => _CategoryPicker(categories: categories),
    );
    if (selected != null) {
      setState(() => _categoryId = selected);
    }
  }

  Future<void> _pickDate() async {
    final picked = await AppDatePickerDialog.showSingle(
      context,
      initial: _date,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = _amountCents;
    final categoryId = _categoryId;
    if (amount == null || categoryId == null) return;

    String? note = _noteCtrl.text.trim();
    if (note.isEmpty) note = null;

    setState(() => _saving = true);
    final repo = ref.read(costRepositoryProvider);
    final e = widget.existing;
    if (e != null) {
      await repo.updateRecord(
        id: e.id,
        categoryId: categoryId,
        amountCents: amount,
        occurredOn: _date,
        note: note,
      );
    } else {
      await repo.addRecord(
        categoryId: categoryId,
        amountCents: amount,
        occurredOn: _date,
        note: note,
      );
      AppHaptics.medium(ref);
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(activeCostCategoriesProvider);
    final categoryName = categoriesAsync.maybeWhen(
      data: (list) {
        final match = list.where((c) => c.id == _categoryId).firstOrNull?.name;
        return match ?? widget.existing?.categoryName;
      },
      orElse: () => widget.existing?.categoryName,
    );

    final canSave = _amountCents != null && _categoryId != null && !_saving;

    return Padding(
      padding: EdgeInsets.only(
        left: UiScale.scale(16),
        right: UiScale.scale(16),
        top: UiScale.scale(12),
        bottom: MediaQuery.of(context).viewInsets.bottom + UiScale.scale(16),
      ),
      // 键盘弹起时可用高度被压缩，内容可滚动避免底部溢出
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Container(
            alignment: Alignment.center,
            padding: EdgeInsets.only(bottom: UiScale.scale(8)),
            child: Text(
              _isEdit ? '编辑采购' : '记一笔采购',
              style: TextStyle(
                fontSize: UiScale.scale(18),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _Field(
            label: '金额（元）',
            child: TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              style: TextStyle(
                fontSize: UiScale.scale(18),
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                hintText: '0.00',
                prefixText: '¥ ',
                border: InputBorder.none,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(height: UiScale.scale(10)),
          _Field(
            label: '类目',
            child: GestureDetector(
              onTap: _pickCategory,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: UiScale.scale(14)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        categoryName ?? '请选择类目',
                        style: TextStyle(
                          fontSize: UiScale.scale(17),
                          fontWeight: FontWeight.w600,
                          color: categoryName != null
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.unfold_more_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: UiScale.scale(10)),
          _Field(
            label: '日期',
            child: GestureDetector(
              onTap: _pickDate,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: UiScale.scale(14)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('yyyy年M月d日 EEE', 'zh_CN').format(_date),
                        style: TextStyle(
                          fontSize: UiScale.scale(17),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: UiScale.scale(10)),
          _Field(
            label: '备注（选填）',
            child: TextField(
              controller: _noteCtrl,
              textInputAction: TextInputAction.done,
              style: TextStyle(fontSize: UiScale.scale(17)),
              decoration: const InputDecoration(
                hintText: '如：批发市场进货',
                border: InputBorder.none,
              ),
            ),
          ),
          SizedBox(height: UiScale.scale(18)),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: UiScale.scale(50),
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
              ),
              SizedBox(width: UiScale.scale(12)),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: UiScale.scale(50),
                  child: FilledButton(
                    onPressed: canSave ? _save : null,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEdit ? '保存' : '记一笔'),
                  ),
                ),
              ),
            ],
          ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: UiScale.scale(14)),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(UiScale.scale(12)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(top: UiScale.scale(8)),
            child: Text(
              label,
              style: TextStyle(
                fontSize: UiScale.scale(12),
                color: AppColors.textMuted,
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// 类目选择弹层：列出启用类目 + 快速新建
class _CategoryPicker extends ConsumerWidget {
  const _CategoryPicker({required this.categories});

  final List<CostCategory> categories;

  Future<void> _quickCreate(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NameDialog(title: '新建类目'),
    );
    if (name == null || name.trim().isEmpty) return;
    final repo = ref.read(costRepositoryProvider);
    if (await repo.nameExists(name.trim())) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('该类目已存在')));
      }
      return;
    }
    final id = await repo.addCategory(name.trim());
    ref.invalidate(activeCostCategoriesProvider);
    if (context.mounted) Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(UiScale.scale(16)),
            child: Text(
              '选择类目',
              style: TextStyle(
                fontSize: UiScale.scale(17),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (categories.isEmpty)
            Padding(
              padding: EdgeInsets.all(UiScale.scale(20)),
              child: Text(
                '暂无类目，请先新建',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final c in categories)
                  ListTile(
                    title: Text(c.name),
                    onTap: () => Navigator.of(context).pop(c.id),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(UiScale.scale(12)),
            child: OutlinedButton.icon(
              onPressed: () => _quickCreate(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('新建类目'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 简单的名称输入弹窗
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title});

  final String title;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: const Text('确定'),
        ),
      ],
    );
  }
}
