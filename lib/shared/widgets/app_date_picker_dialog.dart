import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// 自定义日期选择弹窗：内联日历，套用主题色，中文星期。
/// 返回所选日期（单选返回一个，区间返回起止）。
class AppDatePickerDialog extends StatefulWidget {
  const AppDatePickerDialog({
    super.key,
    required this.rangeMode,
    required this.initial,
    this.firstDate,
    this.lastDate,
  });

  /// true 选择起止区间；false 选择单日
  final bool rangeMode;
  final List<DateTime?> initial;
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// 单日选择
  static Future<DateTime?> showSingle(
    BuildContext context, {
    required DateTime initial,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (_) => AppDatePickerDialog(
        rangeMode: false,
        initial: [initial],
      ),
    );
  }

  /// 区间选择
  static Future<List<DateTime>?> showRange(
    BuildContext context, {
    required DateTime start,
    required DateTime end,
  }) {
    return showDialog<List<DateTime>>(
      context: context,
      builder: (_) => AppDatePickerDialog(
        rangeMode: true,
        initial: [start, end],
      ),
    );
  }

  @override
  State<AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<AppDatePickerDialog> {
  late List<DateTime?> _value = widget.initial;

  /// 中文星期（必须从周日开始）
  static const _weekdays = ['日', '一', '二', '三', '四', '五', '六'];

  bool get _canConfirm {
    if (widget.rangeMode) return _value.length == 2;
    return _value.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final config = CalendarDatePicker2Config(
      calendarType: widget.rangeMode
          ? CalendarDatePicker2Type.range
          : CalendarDatePicker2Type.single,
      firstDate: widget.firstDate ?? DateTime(2020),
      lastDate: widget.lastDate ?? DateTime(2100),
      weekdayLabels: _weekdays,
      firstDayOfWeek: 1, // 周一开头
      // 标题居中，给两侧翻页箭头各留半宽，避免窄弹窗头部溢出
      centerAlignModePicker: true,
      selectedDayHighlightColor: AppColors.selected,
      selectedRangeHighlightColor:
          AppColors.selected.withValues(alpha: 0.12),
      dayBorderRadius: BorderRadius.circular(UiScale.scale(10)),
      controlsTextStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      // 不显示下拉箭头，用零尺寸占位，给标题和翻页键留足宽度
      customModePickerIcon: const SizedBox.shrink(),
      modePickersGap: 6,
      // 直接提供紧凑中文标签，避免依赖全局 locale，同时防止窄弹窗标题溢出
      modePickerTextHandler: ({required monthDate, isMonthPicker}) {
        if (isMonthPicker == true) {
          return '${monthDate.month}月';
        }
        // 不带下拉箭头，宽度足够，恢复「年」后缀
        return '${monthDate.year}年';
      },
      weekdayLabelTextStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textMuted,
      ),
      dayTextStyle: const TextStyle(
        fontSize: 15,
        color: AppColors.textPrimary,
      ),
      selectedDayTextStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
      todayTextStyle: const TextStyle(
        color: AppColors.selected,
        fontWeight: FontWeight.w700,
      ),
      lastMonthIcon: const Icon(Icons.chevron_left_rounded,
          color: AppColors.textPrimary),
      nextMonthIcon: const Icon(Icons.chevron_right_rounded,
          color: AppColors.textPrimary),
    );

    return Dialog(
      backgroundColor: AppColors.surfaceElevated,
      insetPadding: EdgeInsets.symmetric(horizontal: UiScale.scale(24)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(UiScale.scale(20)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          UiScale.scale(12),
          UiScale.scale(16),
          UiScale.scale(12),
          UiScale.scale(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CalendarDatePicker2(
              config: config,
              value: _value,
              onValueChanged: (dates) {
                setState(() {
                  _value = dates.cast<DateTime?>();
                });
              },
            ),
            Divider(height: UiScale.scale(1), color: AppColors.border),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: _canConfirm
                      ? () {
                          if (widget.rangeMode) {
                            Navigator.of(context)
                                .pop(_value.cast<DateTime>());
                          } else {
                            Navigator.of(context).pop(_value.first);
                          }
                        }
                      : null,
                  child: const Text('确定'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
