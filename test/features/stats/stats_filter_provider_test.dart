import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/utils/date_range.dart';
import 'package:hebao_pos/features/stats/providers/stats_filter_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('初始为按日模式，自定义区间默认最近 7 天', () {
    final filter = container.read(statsFilterProvider);
    expect(filter.mode, StatsRangeMode.day);

    final now = DateTime.now();
    expect(startOfDay(filter.day), startOfDay(now));
    expect(
      startOfDay(filter.customStart),
      startOfDay(now.subtract(const Duration(days: 6))),
    );
    expect(startOfDay(filter.customEnd), startOfDay(now));
  });

  test('setDay / setMonth / setCustom / setMode 更新对应字段', () {
    final notifier = container.read(statsFilterProvider.notifier);

    notifier.setDay(DateTime(2026, 9, 15, 10, 30));
    notifier.setMonth(DateTime(2026, 8, 20));
    notifier.setCustom(DateTime(2026, 9, 1), DateTime(2026, 9, 7));
    notifier.setMode(StatsRangeMode.custom);

    final filter = container.read(statsFilterProvider);
    expect(filter.day, DateTime(2026, 9, 15, 10, 30));
    expect(filter.month, DateTime(2026, 8, 20));
    expect(filter.customStart, DateTime(2026, 9, 1));
    expect(filter.customEnd, DateTime(2026, 9, 7));
    expect(filter.mode, StatsRangeMode.custom);
  });

  test('按日模式的 range 为当天半开区间', () {
    container.read(statsFilterProvider.notifier)
      ..setDay(DateTime(2026, 10, 2, 15))
      ..setMode(StatsRangeMode.day);

    final range = container.read(statsFilterProvider).range;
    expect(range.start, DateTime(2026, 10, 2).millisecondsSinceEpoch);
    expect(range.end, DateTime(2026, 10, 3).millisecondsSinceEpoch);
  });

  test('按月模式的 range 覆盖整个自然月', () {
    container.read(statsFilterProvider.notifier)
      ..setMonth(DateTime(2026, 10, 20))
      ..setMode(StatsRangeMode.month);

    final range = container.read(statsFilterProvider).range;
    expect(range.start, DateTime(2026, 10, 1).millisecondsSinceEpoch);
    expect(range.end, DateTime(2026, 11, 1).millisecondsSinceEpoch);
  });

  test('自定义模式的 range 首尾日期均含', () {
    container.read(statsFilterProvider.notifier)
      ..setCustom(DateTime(2026, 10, 1, 8), DateTime(2026, 10, 7, 22))
      ..setMode(StatsRangeMode.custom);

    final range = container.read(statsFilterProvider).range;
    expect(range.start, DateTime(2026, 10, 1).millisecondsSinceEpoch);
    expect(range.end, DateTime(2026, 10, 8).millisecondsSinceEpoch);
  });

  test('copyWith 未指定字段保持原值', () {
    final original = container.read(statsFilterProvider);
    final copy = original.copyWith(mode: StatsRangeMode.month);
    expect(copy.mode, StatsRangeMode.month);
    expect(copy.day, original.day);
    expect(copy.customEnd, original.customEnd);
  });
}
