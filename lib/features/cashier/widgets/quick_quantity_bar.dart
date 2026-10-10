import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../shared/models/order_line.dart';

/// 快捷数量区：头部「清除 / 堂食·打包切换 / 数量 / 提示 / ⌨」+ 2~9（语义为「设为 N」）。
/// 固定占位，未选中商品时弱化并显示引导文案，高度不跳动。
class QuickQuantityBar extends StatelessWidget {
  const QuickQuantityBar({
    super.key,
    required this.hasSelection,
    required this.selectedName,
    required this.channel,
    required this.onChannelChanged,
    required this.onPick,
    required this.onClear,
    required this.onOpenKeyboard,
  });

  final bool hasSelection;
  final String? selectedName;
  final OrderChannel channel;
  final ValueChanged<OrderChannel> onChannelChanged;
  final ValueChanged<int> onPick;
  final VoidCallback onClear;
  final VoidCallback onOpenKeyboard;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: hasSelection ? 1 : 0.5,
      child: Container(
        padding: EdgeInsets.all(UiScale.scale(12)),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(UiScale.scale(20)),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // 「清除」描边按钮：将当前选中商品数量设为 0
                OutlinedButton(
                  onPressed: hasSelection ? onClear : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.symmetric(
                        horizontal: UiScale.scale(14), vertical: UiScale.scale(8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(UiScale.scale(10)),
                    ),
                  ),
                  child: Text(
                    '清除',
                    style: TextStyle(
                      fontSize: UiScale.scale(16),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                SizedBox(width: UiScale.scale(10)),
                Container(width: 1, height: UiScale.scale(34), color: AppColors.border),
                SizedBox(width: UiScale.scale(10)),
                // 堂食 / 打包切换：决定点卡片 +1 与快捷数字落在哪个通道
                _ChannelToggle(
                  channel: channel,
                  onChanged: onChannelChanged,
                ),
                SizedBox(width: UiScale.scale(10)),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      hasSelection ? '$selectedName' : '先点商品卡片',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: UiScale.scale(18),
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: UiScale.scale(8)),
                _KeyboardButton(onTap: hasSelection ? onOpenKeyboard : null),
              ],
            ),
            SizedBox(height: UiScale.scale(12)),
            for (final row in [
              [2, 3, 4, 5],
              [6, 7, 8, 9],
            ])
              Padding(
                padding: EdgeInsets.only(bottom: UiScale.scale(10)),
                child: Row(
                  children: [
                    for (final n in row)
                      Expanded(
                        child: Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: UiScale.scale(7)),
                          child: _Key(
                            label: '$n',
                            onTap: hasSelection ? () => onPick(n) : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 堂食 / 打包两段切换：当前通道实心高亮
class _ChannelToggle extends StatelessWidget {
  const _ChannelToggle({required this.channel, required this.onChanged});

  final OrderChannel channel;
  final ValueChanged<OrderChannel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.button,
        borderRadius: BorderRadius.circular(UiScale.scale(10)),
      ),
      padding: EdgeInsets.all(UiScale.scale(3)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment('堂', OrderChannel.dineIn),
          _segment('外', OrderChannel.takeout),
        ],
      ),
    );
  }

  Widget _segment(String label, OrderChannel value) {
    final active = channel == value;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: UiScale.scale(12),
          vertical: UiScale.scale(6),
        ),
        decoration: BoxDecoration(
          color: active ? AppColors.selected : Colors.transparent,
          borderRadius: BorderRadius.circular(UiScale.scale(8)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: UiScale.scale(16),
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// 头部右侧的方形键盘图标按钮
class _KeyboardButton extends StatelessWidget {
  const _KeyboardButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: EdgeInsets.all(UiScale.scale(8)),
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(UiScale.scale(10)),
        ),
      ),
      child: Icon(Icons.keyboard_outlined,
          size: UiScale.scale(24), color: AppColors.textPrimary),
    );
  }
}

/// 浅灰方形按键：无水波纹
class _Key extends StatelessWidget {
  const _Key({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: UiScale.scale(50),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.button,
          borderRadius: BorderRadius.circular(UiScale.scale(12)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: TextStyle(
              fontSize: UiScale.scale(24),
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
