import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../shared/widgets/app_date_picker_dialog.dart';
import '../providers/stats_filter_provider.dart';

/// 统计页时间筛选栏：日 / 月 / 自定义 三段切换 + 当前区间选择
class StatsFilterBar extends ConsumerWidget {
  const StatsFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(statsFilterProvider);
    final notifier = ref.read(statsFilterProvider.notifier);

    String label;
    switch (filter.mode) {
      case StatsRangeMode.day:
        label = DateFormat('yyyy年M月d日 EEE', 'zh_CN').format(filter.day);
      case StatsRangeMode.month:
        label = DateFormat('yyyy年M月', 'zh_CN').format(filter.month);
      case StatsRangeMode.custom:
        label =
            '${DateFormat('M月d日', 'zh_CN').format(filter.customStart)} - '
            '${DateFormat('M月d日', 'zh_CN').format(filter.customEnd)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final mode in StatsRangeMode.values)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: mode == StatsRangeMode.values.last
                        ? 0
                        : UiScale.scale(8),
                  ),
                  child: _ModeButton(
                    title: switch (mode) {
                      StatsRangeMode.day => '按日',
                      StatsRangeMode.month => '按月',
                      StatsRangeMode.custom => '自定义',
                    },
                    selected: filter.mode == mode,
                    onTap: () => notifier.setMode(mode),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: UiScale.scale(10)),
        GestureDetector(
          onTap: () => _pickRange(context, ref),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: UiScale.scale(14),
              vertical: UiScale.scale(12),
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(UiScale.scale(12)),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 18, color: AppColors.selected),
                SizedBox(width: UiScale.scale(8)),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: UiScale.scale(15),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final filter = ref.read(statsFilterProvider);
    final notifier = ref.read(statsFilterProvider.notifier);

    if (filter.mode == StatsRangeMode.day) {
      final picked =
          await AppDatePickerDialog.showSingle(context, initial: filter.day);
      if (picked != null) notifier.setDay(picked);
    } else if (filter.mode == StatsRangeMode.month) {
      final picked = await _pickMonth(context, filter.month);
      if (picked != null) notifier.setMonth(picked);
    } else {
      final picked = await AppDatePickerDialog.showRange(
        context,
        start: filter.customStart,
        end: filter.customEnd,
      );
      if (picked != null && picked.length == 2) {
        notifier.setCustom(picked[0], picked[1]);
      }
    }
  }

  /// 月份选择弹窗：年份可左右切换，12 个月网格点选
  Future<DateTime?> _pickMonth(BuildContext context, DateTime initial) {
    return showDialog<DateTime>(
      context: context,
      builder: (context) => _MonthPickerDialog(initial: initial),
    );
  }
}

class _MonthPickerDialog extends StatefulWidget {
  const _MonthPickerDialog({required this.initial});

  final DateTime initial;

  @override
  State<_MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<_MonthPickerDialog> {
  late int _year = widget.initial.year;
  late final int _selectedMonth = widget.initial.month;

  static const _monthNames = [
    '1月', '2月', '3月', '4月', '5月', '6月',
    '7月', '8月', '9月', '10月', '11月', '12月',
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiScale.scale(16)),
      ),
      child: Padding(
        padding: EdgeInsets.all(UiScale.scale(16)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Text(
                  '$_year 年',
                  style: TextStyle(
                    fontSize: UiScale.scale(18),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: UiScale.scale(8),
              crossAxisSpacing: UiScale.scale(8),
              children: [
                for (var m = 1; m <= 12; m++)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context)
                          .pop(DateTime(_year, m, 1));
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _year == widget.initial.year &&
                                m == _selectedMonth
                            ? AppColors.selected
                            : AppColors.background,
                        borderRadius:
                            BorderRadius.circular(UiScale.scale(10)),
                      ),
                      child: Text(
                        _monthNames[m - 1],
                        style: TextStyle(
                          fontSize: UiScale.scale(14),
                          fontWeight: FontWeight.w600,
                          color: _year == widget.initial.year &&
                                  m == _selectedMonth
                              ? Colors.white
                              : AppColors.textPrimary,
                        ),
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

class _ModeButton extends StatefulWidget {
  const _ModeButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: UiScale.scale(10)),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.selected
                ? AppColors.selected
                : AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(UiScale.scale(12)),
            border: Border.all(
              color: widget.selected ? AppColors.selected : AppColors.border,
            ),
          ),
          child: Text(
            widget.title,
            style: TextStyle(
              fontSize: UiScale.scale(15),
              fontWeight: FontWeight.w700,
              color: widget.selected
                  ? Colors.white
                  : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
