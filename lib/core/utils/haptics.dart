import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_provider.dart';

/// 统一震动入口：先读「震动反馈」总开关，关闭时不触发。
///
/// 用法（在已持有 WidgetRef 处）：
///   AppHaptics.light(ref);
///   AppHaptics.medium(ref);
class AppHaptics {
  AppHaptics._();

  /// 轻微震动（商品点按）
  static void light(WidgetRef ref) {
    if (ref.read(settingsProvider).hapticEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  /// 稍明显震动（结账 / 删除 / 重要操作）
  static void medium(WidgetRef ref) {
    if (ref.read(settingsProvider).hapticEnabled) {
      HapticFeedback.mediumImpact();
    }
  }
}
