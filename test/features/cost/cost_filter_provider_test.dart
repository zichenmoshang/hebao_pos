import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/utils/date_range.dart';
import 'package:hebao_pos/features/cost/providers/cost_filter_provider.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('初始为按日模式，自定义区间默认最近 7 天', () {
    final filter = container.read(costFilterProvider);
    expect(filter.mode, CostRangeMode.day);

    final now = DateTime.now();
    expect(startOfDay(filter.day), startOfDay(now));
    expect(
      startOfDay(filter.customStart),
      startOfDay(now.subtract(const Duration(days: 6))),
    );
    expect(startOfDay(filter.customEnd), startOfDay(now));
  });

  test('setDay / setMonth / setCustom / setMode 更新对应字段', () {
    final notifier = container.read(costFilterProvider.notifier);

    notifier.setDay(DateTime(2026, 9, 15, 10, 30));
    notifier.setMonth(DateTime(2026, 8, 20));
    notifier.setCustom(DateTime(2026, 9, 1), DateTime(2026, 9, 7));
    notifier.setMode(CostRangeMode.custom);

    final filter = container.read(costFilterProvider);
    expect(filter.day, DateTime(2026, 9, 15, 10, 30));
    expect(filter.month, DateTime(2026, 8, 20));
    expect(filter.customStart, DateTime(2026, 9, 1));
    expect(filter.customEnd, DateTime(2026, 9, 7));
    expect(filter.mode, CostRangeMode.custom);
  });

  test('按日模式的 range 为当天半开区间', () {
    container.read(costFilterProvider.notifier)
      ..setDay(DateTime(2026, 10, 2, 15))
      ..setMode(CostRangeMode.day);

    final range = container.read(costFilterProvider).range;
    expect(range.start, DateTime(2026, 10, 2).millisecondsSinceEpoch);
    expect(range.end, DateTime(2026, 10, 3).millisecondsSinceEpoch);
  });

  test('按月模式的 range 覆盖整个自然月', () {
    container.read(costFilterProvider.notifier)
      ..setMonth(DateTime(2026, 10, 20))
      ..setMode(CostRangeMode.month);

    final range = container.read(costFilterProvider).range;
    expect(range.start, DateTime(2026, 10, 1).millisecondsSinceEpoch);
    expect(range.end, DateTime(2026, 11, 1).millisecondsSinceEpoch);
  });

  test('自定义模式的 range 首尾日期均含', () {
    container.read(costFilterProvider.notifier)
      ..setCustom(DateTime(2026, 10, 1, 8), DateTime(2026, 10, 7, 22))
      ..setMode(CostRangeMode.custom);

    final range = container.read(costFilterProvider).range;
    expect(range.start, DateTime(2026, 10, 1).millisecondsSinceEpoch);
    expect(range.end, DateTime(2026, 10, 8).millisecondsSinceEpoch);
  });

  test('copyWith 未指定字段保持原值', () {
    final original = container.read(costFilterProvider);
    final copy = original.copyWith(mode: CostRangeMode.month);
    expect(copy.mode, CostRangeMode.month);
    expect(copy.day, original.day);
    expect(copy.customStart, original.customStart);
  });
}
