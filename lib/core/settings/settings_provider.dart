import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 屏幕无操作多久后息屏（秒）；0 表示常亮
enum ScreenIdle {
  alwaysOn(0, '常亮'),
  oneMinute(60, '1 分钟'),
  twoMinutes(120, '2 分钟'),
  fiveMinutes(300, '5 分钟');

  const ScreenIdle(this.seconds, this.label);

  final int seconds;
  final String label;

  static ScreenIdle fromSeconds(int seconds) =>
      ScreenIdle.values.firstWhere(
        (e) => e.seconds == seconds,
        orElse: () => ScreenIdle.alwaysOn,
      );
}

/// 设置项领域状态
class AppSettings {
  const AppSettings({
    this.hapticEnabled = true,
    this.screenIdle = ScreenIdle.alwaysOn,
  });

  final bool hapticEnabled;
  final ScreenIdle screenIdle;

  AppSettings copyWith({
    bool? hapticEnabled,
    ScreenIdle? screenIdle,
  }) {
    return AppSettings(
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      screenIdle: screenIdle ?? this.screenIdle,
    );
  }
}

/// 供 main 在启动时覆盖为已加载实例，保证设置 provider 同步可用
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('应在 ProviderScope 覆盖 SharedPreferences 实例');
});

class SettingsNotifier extends Notifier<AppSettings> {
  static const _keyHaptic = 'haptic_enabled';
  static const _keyScreenIdle = 'screen_idle_seconds';

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      hapticEnabled: prefs.getBool(_keyHaptic) ?? true,
      screenIdle:
          ScreenIdle.fromSeconds(prefs.getInt(_keyScreenIdle) ?? 0),
    );
  }

  Future<void> setHapticEnabled(bool enabled) async {
    state = state.copyWith(hapticEnabled: enabled);
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_keyHaptic, enabled);
  }

  Future<void> setScreenIdle(ScreenIdle idle) async {
    state = state.copyWith(screenIdle: idle);
    await ref
        .read(sharedPreferencesProvider)
        .setInt(_keyScreenIdle, idle.seconds);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
