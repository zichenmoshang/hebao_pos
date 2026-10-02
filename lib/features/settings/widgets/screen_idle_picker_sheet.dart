import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/settings/settings_provider.dart';

/// 屏幕常亮选择弹窗：常亮 / 1 / 2 / 5 分钟
class ScreenIdlePickerSheet extends StatelessWidget {
  const ScreenIdlePickerSheet({super.key, required this.selected});

  final ScreenIdle selected;

  static Future<ScreenIdle?> show(
      BuildContext context, ScreenIdle selected) {
    return showModalBottomSheet<ScreenIdle>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UiScale.scale(18)),
        ),
      ),
      builder: (_) => ScreenIdlePickerSheet(selected: selected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(UiScale.scale(16)),
            child: Text(
              '无操作多久后息屏',
              style: TextStyle(
                fontSize: UiScale.scale(17),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          for (final option in ScreenIdle.values)
            ListTile(
              title: Text(option.label),
              trailing: option == selected
                  ? const Icon(Icons.check_rounded,
                      color: AppColors.selected)
                  : null,
              onTap: () => Navigator.of(context).pop(option),
            ),
          SizedBox(height: UiScale.scale(8)),
        ],
      ),
    );
  }
}
