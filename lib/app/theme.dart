import 'package:flutter/material.dart';

/// 设计令牌：浅色高对比收银风格（按高保真原型）。
/// 暖灰底 + 白色卡片，青色（teal）作为主行动点与金额色，忙乱环境中一眼可辨。
class AppColors {
  AppColors._();

  static const background = Color(0xFFF4F2EF); // 暖灰页面底
  static const surface = Color(0xFFFFFFFF); // 商品卡片
  static const surfaceElevated = Color(0xFFFFFFFF); // 快捷数量区容器
  static const activeBand = Color(0xFFBFE3E2); // 已点商品卡片底部青色带
  static const button = Color(0xFFE3E3E3); // 快捷区数字按键
  static const border = Color(0xFFD8D6D2); // 未选中描边 / 分割线
  static const selected = Color(0xFF0E7C86); // 青色：金额 / 主按钮 / 选中描边
  static const textPrimary = Color(0xFF1F2A2D);
  static const textSecondary = Color(0xFF666666); // 提示文案 / 明细
  static const textMuted = Color(0xFF8A8F92); // 弱化文案
  static const danger = Color(0xFFE5534B); // 清零
}

/// 以 375 逻辑宽（常见手机）为设计基准，按当前屏宽等比缩放。
/// 小屏（如 320 宽模拟器）自动收窄字号 / 高度，保证网格不被挤压、文字不溢出。
class UiScale {
  UiScale._();

  static double _factor = 1;
  static double _dpr = 1;

  /// 需在页面顶部初始化一次
  static void init(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    _factor = (w / 375).clamp(0.78, 1.15);
    _dpr = MediaQuery.devicePixelRatioOf(context);
  }

  static double get s => _factor;

  /// 设计值 → 当前屏缩放值
  static double scale(double value) => value * _factor;

  /// 对齐到物理像素网格：换算为物理像素取整后再折回逻辑像素，
  /// 让边缘恰好压在物理像素边界，消除圆角 / 描边的抗锯齿毛边
  static double snap(double value) => (value * _dpr).roundToDouble() / _dpr;
}

class AppTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: AppColors.selected,
      onPrimary: Color(0xFFFFFFFF),
      secondary: AppColors.selected,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: null,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textMuted),
      ),
    );
  }
}
