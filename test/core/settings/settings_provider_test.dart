import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/settings/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> makeContainer(Map<String, Object> initial) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  group('AppSettings', () {
    test('copyWith 仅覆盖指定字段', () {
      const base = AppSettings();
      final copy = base.copyWith(screenIdle: ScreenIdle.oneMinute);
      expect(copy.hapticEnabled, isTrue);
      expect(copy.screenIdle, ScreenIdle.oneMinute);
      // 原对象不变
      expect(base.screenIdle, ScreenIdle.alwaysOn);
    });
  });

  group('ScreenIdle.fromSeconds', () {
    test('已知秒数映射到对应档位', () {
      expect(ScreenIdle.fromSeconds(0), ScreenIdle.alwaysOn);
      expect(ScreenIdle.fromSeconds(60), ScreenIdle.oneMinute);
      expect(ScreenIdle.fromSeconds(120), ScreenIdle.twoMinutes);
      expect(ScreenIdle.fromSeconds(300), ScreenIdle.fiveMinutes);
    });

    test('未知秒数回退为常亮', () {
      expect(ScreenIdle.fromSeconds(999), ScreenIdle.alwaysOn);
    });
  });

  group('SettingsNotifier', () {
    test('无持久化值时使用默认值：震动开、常亮', () async {
      final container = await makeContainer({});
      final settings = container.read(settingsProvider);
      expect(settings.hapticEnabled, isTrue);
      expect(settings.screenIdle, ScreenIdle.alwaysOn);
    });

    test('启动时读取已持久化的设置', () async {
      final container = await makeContainer({
        'haptic_enabled': false,
        'screen_idle_seconds': 120,
      });
      final settings = container.read(settingsProvider);
      expect(settings.hapticEnabled, isFalse);
      expect(settings.screenIdle, ScreenIdle.twoMinutes);
    });

    test('setHapticEnabled 更新状态并写入持久化', () async {
      final container = await makeContainer({});
      await container.read(settingsProvider.notifier).setHapticEnabled(false);

      expect(container.read(settingsProvider).hapticEnabled, isFalse);

      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getBool('haptic_enabled'), isFalse);
    });

    test('setScreenIdle 更新状态并写入持久化', () async {
      final container = await makeContainer({});
      await container
          .read(settingsProvider.notifier)
          .setScreenIdle(ScreenIdle.fiveMinutes);

      expect(container.read(settingsProvider).screenIdle,
          ScreenIdle.fiveMinutes);

      final prefs = container.read(sharedPreferencesProvider);
      expect(prefs.getInt('screen_idle_seconds'), 300);
    });
  });
}
