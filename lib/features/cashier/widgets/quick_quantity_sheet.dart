import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// 大数量快捷点选弹层：10~30 共 21 键，点中即「设为 N」并关闭。
/// 小于 10 用主界面快捷区 / 点卡片，清零用快捷区「清除」，
/// 实际大单不超过 30，故不提供键盘输入
class QuickQuantitySheet extends StatelessWidget {
  const QuickQuantitySheet({super.key});

  static Future<int?> show(BuildContext context) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UiScale.scale(24)),
        ),
      ),
      builder: (_) => const QuickQuantitySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(UiScale.scale(999)),
                ),
              ),
            ),
            SizedBox(height: UiScale.scale(12)),
            // 4 列大键排布：弹层空间充足，键宽、键高都放大，湿手也好按
            for (final row in [
              [10, 11, 12, 13],
              [14, 15, 16, 17],
              [18, 19, 20, 21],
              [22, 23, 24, 25],
              [26, 27, 28, 29],
            ])
              Padding(
                padding: EdgeInsets.only(bottom: UiScale.scale(12)),
                child: Row(
                  children: [
                    for (final n in row)
                      Expanded(
                        child: _QuickKey(
                          label: '$n',
                          onTap: () => Navigator.pop(context, n),
                        ),
                      ),
                  ],
                ),
              ),
            // 30 独占一行全宽：最大单值，放最底部最好够
            _QuickKey(label: '30', onTap: () => Navigator.pop(context, 30)),
          ],
        ),
      ),
    );
  }
}

/// 快捷档位大键：按下轻缩放
class _QuickKey extends StatefulWidget {
  const _QuickKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_QuickKey> createState() => _QuickKeyState();
}

class _QuickKeyState extends State<_QuickKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: UiScale.scale(6)),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            height: UiScale.scale(64),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.button,
              borderRadius: BorderRadius.circular(UiScale.scale(16)),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: UiScale.scale(26),
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
