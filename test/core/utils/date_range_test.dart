import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/utils/date_range.dart';

void main() {
  test('startOfDay 归零时分秒', () {
    expect(
      startOfDay(DateTime(2026, 10, 2, 13, 45, 30)),
      DateTime(2026, 10, 2),
    );
  });

  test('startOfNextDay 指向次日零点', () {
    expect(
      startOfNextDay(DateTime(2026, 10, 2, 23, 59)),
      DateTime(2026, 10, 3),
    );
  });

  test('dayRange 为当天零点到次日零点的半开区间', () {
    final range = dayRange(DateTime(2026, 10, 2, 8));
    expect(range.start, DateTime(2026, 10, 2).millisecondsSinceEpoch);
    expect(range.end, DateTime(2026, 10, 3).millisecondsSinceEpoch);
    expect(range.days, 1);
  });

  test('monthRange 覆盖自然月并正确跨年', () {
    final october = monthRange(2026, 10);
    expect(october.start, DateTime(2026, 10, 1).millisecondsSinceEpoch);
    expect(october.end, DateTime(2026, 11, 1).millisecondsSinceEpoch);
    expect(october.days, 31);

    final december = monthRange(2026, 12);
    expect(december.end, DateTime(2027, 1, 1).millisecondsSinceEpoch);
  });

  test('customRange 首尾日期均含，终点为结束日次日零点', () {
    final range = customRange(
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 7),
    );
    expect(range.start, DateTime(2026, 10, 1).millisecondsSinceEpoch);
    expect(range.end, DateTime(2026, 10, 8).millisecondsSinceEpoch);
    expect(range.days, 7);
  });
}
