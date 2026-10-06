import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/settings/keep_awake_controller.dart';
import 'package:hebao_pos/core/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

class _FakeWakelock extends WakelockPlusPlatformInterface {
  final List<bool> calls = [];
  bool _enabled = false;

  @override
  Future<void> toggle({required bool enable}) async {
    calls.add(enable);
    _enabled = enable;
  }

  @override
  Future<bool> get enabled async => _enabled;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeWakelock fakeWakelock;

  setUp(() {
    fakeWakelock = _FakeWakelock();
    wakelockPlusPlatformInstance = fakeWakelock;
  });

  Future<WidgetRef> pumpRef(
    WidgetTester tester,
    Map<String, Object> initialPrefs,
  ) async {
    SharedPreferences.setMockInitialValues(initialPrefs);
    final prefs = await SharedPreferences.getInstance();
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              captured = ref;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    return captured;
  }

  testWidgets('常亮档：start 持有 wakelock，交互不重复触发，dispose 释放',
      (tester) async {
    final ref = await pumpRef(tester, {});
    final controller = KeepAwakeController(ref);

    controller.start();
    expect(fakeWakelock.calls, [true]);

    // 常亮档无需计时，交互不产生额外调用
    controller.onUserInteraction();
    expect(fakeWakelock.calls, [true]);

    controller.dispose();
    expect(fakeWakelock.calls, [true, false]);
  });

  testWidgets('限时档：交互重新持有并重置计时', (tester) async {
    final ref = await pumpRef(tester, {'screen_idle_seconds': 60});
    final controller = KeepAwakeController(ref);

    controller.start();
    expect(fakeWakelock.calls, [true]);

    controller.onUserInteraction();
    expect(fakeWakelock.calls, [true, true]);

    controller.dispose();
    expect(fakeWakelock.calls, [true, true, false]);
  });

  testWidgets('运行中修改息屏设置会重新应用 wakelock', (tester) async {
    final ref = await pumpRef(tester, {});
    final controller = KeepAwakeController(ref);

    controller.start();
    expect(fakeWakelock.calls, [true]);

    await ref
        .read(settingsProvider.notifier)
        .setScreenIdle(ScreenIdle.fiveMinutes);
    expect(fakeWakelock.calls, [true, true]);

    controller.dispose();
  });
}
