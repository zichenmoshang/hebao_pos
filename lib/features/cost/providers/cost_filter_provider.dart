import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_range.dart';

/// 时间筛选模式
enum CostRangeMode { day, month, custom }

/// 成本页当前时间筛选状态
class CostFilter {
  const CostFilter({
    this.mode = CostRangeMode.day,
    required this.day,
    required this.month,
    required this.customStart,
    required this.customEnd,
  });

  final DateTime day;
  final DateTime month;
  final DateTime customStart;
  final DateTime customEnd;
  final CostRangeMode mode;

  /// 当前筛选对应的半开区间
  DateRange get range {
    switch (mode) {
      case CostRangeMode.day:
        return dayRange(day);
      case CostRangeMode.month:
        return monthRange(month.year, month.month);
      case CostRangeMode.custom:
        return customRange(customStart, customEnd);
    }
  }

  CostFilter copyWith({
    CostRangeMode? mode,
    DateTime? day,
    DateTime? month,
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    return CostFilter(
      mode: mode ?? this.mode,
      day: day ?? this.day,
      month: month ?? this.month,
      customStart: customStart ?? this.customStart,
      customEnd: customEnd ?? this.customEnd,
    );
  }
}

class CostFilterNotifier extends Notifier<CostFilter> {
  @override
  CostFilter build() {
    final now = DateTime.now();
    return CostFilter(
      day: now,
      month: now,
      customStart: now.subtract(const Duration(days: 6)),
      customEnd: now,
    );
  }

  void setMode(CostRangeMode mode) => state = state.copyWith(mode: mode);
  void setDay(DateTime d) => state = state.copyWith(day: d);
  void setMonth(DateTime m) => state = state.copyWith(month: m);
  void setCustom(DateTime start, DateTime end) =>
      state = state.copyWith(customStart: start, customEnd: end);
}

final costFilterProvider =
    NotifierProvider<CostFilterNotifier, CostFilter>(
  CostFilterNotifier.new,
);
