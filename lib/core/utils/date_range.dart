/// 日期区间工具：统一按设备本地日期切分（单店无时区问题）。
/// 订单区间一律用「含起点、不含终点」的半开区间 [start, end)。
class DateRange {
  const DateRange(this.start, this.end);

  /// 起始（含），Unix 毫秒
  final int start;

  /// 结束（不含），Unix 毫秒
  final int end;

  /// 区间跨越的自然日数（至少 1）
  int get days =>
      DateTime.fromMillisecondsSinceEpoch(end)
          .difference(DateTime.fromMillisecondsSinceEpoch(start))
          .inDays;
}

/// 当天本地 0 点
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// 次日本地 0 点
DateTime startOfNextDay(DateTime d) =>
    DateTime(d.year, d.month, d.day)
        .add(const Duration(days: 1));

/// 某自然日对应的半开区间
DateRange dayRange(DateTime d) {
  final start = startOfDay(d);
  return DateRange(
    start.millisecondsSinceEpoch,
    start.add(const Duration(days: 1)).millisecondsSinceEpoch,
  );
}

/// 某自然月对应的半开区间：[月初 0 点, 下月 1 日 0 点)
DateRange monthRange(int year, int month) {
  final start = DateTime(year, month, 1);
  final end = DateTime(year, month + 1, 1);
  return DateRange(
    start.millisecondsSinceEpoch,
    end.millisecondsSinceEpoch,
  );
}

/// 自定义起止日期（均含首尾）：从 startDay 0 点 到 endDay 次日 0 点
DateRange customRange(DateTime startDay, DateTime endDay) {
  final s = startOfDay(startDay);
  final e = startOfDay(endDay).add(const Duration(days: 1));
  return DateRange(
    s.millisecondsSinceEpoch,
    e.millisecondsSinceEpoch,
  );
}
