import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../app/theme.dart';
import '../../../core/database/app_database_provider.dart';
import '../../../core/repositories/product_repository.dart';
import '../../../core/services/csv_export_service.dart';
import '../../../core/settings/settings_provider.dart';
import '../../../core/utils/date_range.dart';
import '../../../shared/widgets/app_date_picker_dialog.dart';
import '../../cashier/providers/current_order_provider.dart';
import '../../products/screens/products_screen.dart';
import '../widgets/screen_idle_picker_sheet.dart';

/// 设置：低频配置统一入口，按「通用 / 数据」分组
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// 初始化入口连点计数；需连点 6 次才弹出二次确认
  int _initTapCount = 0;

  /// 上一次点击时间，超时（2 秒）未续点则计数清零
  DateTime? _lastInitTap;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('zh_CN');
  }

  /// 点击底部隐藏的初始化入口
  void _onInitHiddenTap() {
    final now = DateTime.now();
    final last = _lastInitTap;
    if (last == null || now.difference(last) > const Duration(seconds: 2)) {
      _initTapCount = 0;
    }
    _lastInitTap = now;
    _initTapCount++;

    if (_initTapCount >= 6) {
      _initTapCount = 0;
      _confirmInit();
    }
  }

  /// 二次确认后执行初始化
  Future<void> _confirmInit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('初始化数据'),
        content: const Text(
          '将清空全部订单、商品、成本等业务数据，并恢复默认 5 个商品。\n\n此操作不可恢复，确定继续吗？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确定初始化'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    // 清空商品图片文件
    try {
      final dir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(p.join(dir.path, 'product_images'));
      if (await imagesDir.exists()) {
        await imagesDir.delete(recursive: true);
      }
    } catch (_) {
      // 图片清理失败不阻断数据初始化
    }

    await ref.read(appDatabaseProvider).clearAllData();
    // 清库前同步清空内存中的未结账订单，避免旧 productId 在新库触发外键失败或数据污染
    ref.read(currentOrderProvider.notifier).clear();
    // 清库后重新写入默认 5 个商品种子（商品管理页直接读表、不会自动建种子）
    await ref.read(productRepositoryProvider).ensureSeeded();
    // 失效数据库实例，所有依赖它的商品 / 统计 / 成本 provider 均会重算
    ref.invalidate(appDatabaseProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('数据已初始化')),
    );
  }

  Future<void> _export() async {
    // 先选时间区间，再导出
    final now = DateTime.now();
    final startCtrl = DateTime(now.year, now.month, 1);
    final pickedRange = await showModalBottomSheet<_ExportRange>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UiScale.scale(18)),
        ),
      ),
      builder: (_) => _ExportRangePicker(
        initialStart: startCtrl,
        initialEnd: now,
      ),
    );
    if (pickedRange == null) return;

    await _doExport(pickedRange);
  }

  Future<void> _doExport(_ExportRange pickedRange) async {
    try {
      await ref.read(csvExportServiceProvider).export(
            pickedRange.range,
            pickedRange.start,
            pickedRange.end,
          );
    } on ExportEmptyException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('所选区间暂无可导出的数据')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    UiScale.init(context);
    final settings = ref.watch(settingsProvider);
    final pad = UiScale.scale(12);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(pad),
          children: [
            _GroupTitle('通用'),
            _CardShell(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('震动反馈'),
                    subtitle: const Text('点按商品、结账等操作的震动'),
                    value: settings.hapticEnabled,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.selected,
                    onChanged: (v) =>
                        ref.read(settingsProvider.notifier).setHapticEnabled(v),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('屏幕常亮'),
                    subtitle: Text(
                      settings.screenIdle == ScreenIdle.alwaysOn
                          ? '保持常亮'
                          : '${settings.screenIdle.label}无操作后息屏',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                    onTap: () async {
                      final picked = await ScreenIdlePickerSheet.show(
                        context,
                        settings.screenIdle,
                      );
                      if (picked != null) {
                        await ref
                            .read(settingsProvider.notifier)
                            .setScreenIdle(picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: pad),
            _GroupTitle('数据'),
            _CardShell(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.upload_file_outlined,
                        color: AppColors.selected),
                    title: const Text('导出数据'),
                    subtitle: const Text('按区间导出订单与采购 Excel'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                    onTap: _export,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.inventory_2_outlined,
                        color: AppColors.selected),
                    title: const Text('商品管理'),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textMuted),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const ProductsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: pad),
            // 隐藏的初始化入口：低调文字，需连点 6 次 + 二次确认
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onInitHiddenTap,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: UiScale.scale(10)),
                child: Center(
                  child: Text(
                    '和宝小吃',
                    style: TextStyle(
                      fontSize: UiScale.scale(12),
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: UiScale.scale(4),
        bottom: UiScale.scale(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: UiScale.scale(14),
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: UiScale.scale(14)),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(UiScale.scale(14)),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// 导出区间选择结果
class _ExportRange {
  const _ExportRange({
    required this.start,
    required this.end,
    required this.range,
  });

  final DateTime start;
  final DateTime end;
  final DateRange range;
}

/// 导出前选区间：起始 / 结束日期两行
class _ExportRangePicker extends StatefulWidget {
  const _ExportRangePicker({
    required this.initialStart,
    required this.initialEnd,
  });

  final DateTime initialStart;
  final DateTime initialEnd;

  @override
  State<_ExportRangePicker> createState() => _ExportRangePickerState();
}

class _ExportRangePickerState extends State<_ExportRangePicker> {
  late DateTime _start = widget.initialStart;
  late DateTime _end = widget.initialEnd;

  bool get _valid => !_end.isBefore(_start);

  Future<void> _pickStart() async {
    final picked =
        await AppDatePickerDialog.showSingle(context, initial: _start);
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final picked =
        await AppDatePickerDialog.showSingle(context, initial: _end);
    if (picked != null) setState(() => _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(UiScale.scale(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '选择导出区间',
              style: TextStyle(
                fontSize: UiScale.scale(17),
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: UiScale.scale(12)),
            _DateRow(
              label: '开始日期',
              date: _start,
              onTap: _pickStart,
            ),
            SizedBox(height: UiScale.scale(10)),
            _DateRow(
              label: '结束日期',
              date: _end,
              onTap: _pickEnd,
            ),
            if (!_valid)
              Padding(
                padding: EdgeInsets.only(top: UiScale.scale(8)),
                child: Text(
                  '结束日期不能早于开始日期',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: UiScale.scale(13),
                  ),
                ),
              ),
            SizedBox(height: UiScale.scale(18)),
            SizedBox(
              height: UiScale.scale(50),
              child: FilledButton(
                onPressed: _valid
                    ? () => Navigator.of(context).pop(
                          _ExportRange(
                            start: _start,
                            end: _end,
                            range: customRange(_start, _end),
                          ),
                        )
                    : null,
                child: const Text('确定并导出'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
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
          borderRadius: BorderRadius.circular(UiScale.scale(12)),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: UiScale.scale(15),
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              DateFormat('yyyy年M月d日', 'zh_CN').format(date),
              style: TextStyle(
                fontSize: UiScale.scale(16),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
