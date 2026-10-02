import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'settings_provider.dart';

/// 屏幕常亮控制：按设置在收银页持有 / 释放 wakelock。
///
/// - 设置为「常亮」：进入页面即持有 wakelock
/// - 设置为 X 分钟：每次用户交互重置计时，X 秒无操作后释放 wakelock，
///   随后跟随系统超时息屏；再次交互重新持有并计时
///
/// 用法：
///   final controller = KeepAwakeController(ref);
///   controller.start();
///   // 用 Listener/手势把每次交互传给 controller.onUserInteraction();
///   controller.dispose();
class KeepAwakeController {
  KeepAwakeController(this._ref);

  final WidgetRef _ref;
  Timer? _idleTimer;
  ProviderSubscription<ScreenIdle>? _sub;
  bool _disposed = false;

  void start() {
    _apply();
    _sub = _ref.listenManual(
      settingsProvider.select((s) => s.screenIdle),
      (_, _) => _apply(),
    );
  }

  /// 用户有任意交互时调用
  void onUserInteraction() {
    if (_disposed) return;
    final seconds = _ref.read(settingsProvider).screenIdle.seconds;
    if (seconds == 0) return; // 常亮档无需计时
    // 交互后重新持有并重置计时
    WakelockPlus.enable();
    _restartTimer(seconds);
  }

  void _apply() {
    if (_disposed) return;
    final seconds = _ref.read(settingsProvider).screenIdle.seconds;
    _idleTimer?.cancel();
    WakelockPlus.enable();
    if (seconds != 0) {
      // 限时档：先持有，等空闲到期释放
      _restartTimer(seconds);
    }
  }

  void _restartTimer(int seconds) {
    _idleTimer?.cancel();
    _idleTimer = Timer(Duration(seconds: seconds), () {
      WakelockPlus.disable();
    });
  }

  void dispose() {
    _disposed = true;
    _idleTimer?.cancel();
    _sub?.close();
    WakelockPlus.disable();
  }
}
