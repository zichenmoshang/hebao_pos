import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_range.dart';

/// 时间筛选模式
enum StatsRangeMode { day, month, custom }

/// 统计页当前时间筛选状态
class StatsFilter {
  const StatsFilter({
    this.mode = StatsRangeMode.day,
    required this.day,
    required this.month,
    required this.customStart,
    required this.customEnd,
  });

  /// 按日时选中的日期
  final DateTime day;

  /// 按月时选中的月份（取年月，日忽略）
  final DateTime month;

  /// 自定义起止日期
  final DateTime customStart;
  final DateTime customEnd;

  final StatsRangeMode mode;

  /// 当前筛选对应的半开区间
  DateRange get range {
    switch (mode) {
      case StatsRangeMode.day:
        return dayRange(day);
      case StatsRangeMode.month:
        return monthRange(month.year, month.month);
      case StatsRangeMode.custom:
        return customRange(customStart, customEnd);
    }
  }

  StatsFilter copyWith({
    StatsRangeMode? mode,
    DateTime? day,
    DateTime? month,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    return StatsFilter(
      mode: mode ?? this.mode,
      day: day ?? this.day,
      month: month ?? this.month,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
    );
  }
}

class StatsFilterNotifier extends Notifier<StatsFilter> {
  @override
  StatsFilter build() {
    final now = DateTime.now();
    return StatsFilter(
      day: now,
      month: now,
      customStart: now.subtract(const Duration(days: 6)),
      customEnd: now,
    );
  }

  void setMode(StatsRangeMode mode) => state = state.copyWith(mode: mode);
  void setDay(DateTime d) => state = state.copyWith(day: d);
  void setMonth(DateTime m) => state = state.copyWith(month: m);
  void setCustom(DateTime start, DateTime end) =>
      state = state.copyWith(customStart: start, customEnd: end);
}

final statsFilterProvider =
    NotifierProvider<StatsFilterNotifier, StatsFilter>(
  StatsFilterNotifier.new,
);
