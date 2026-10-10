import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// 大数量例外单：底部弹出大数字键盘。
/// 顶部 10~30 快捷档位点中即「设为 N」并关闭；下方 0~9 键盘输入为替换式，确定后「设为 N」
class QuantityPadSheet extends StatefulWidget {
  const QuantityPadSheet({super.key, this.initial = 1});

  final int initial;

  static Future<int?> show(BuildContext context, {int initial = 1}) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(UiScale.scale(24))),
      ),
      builder: (_) => QuantityPadSheet(initial: initial),
    );
  }

  @override
  State<QuantityPadSheet> createState() => _QuantityPadSheetState();
}

class _QuantityPadSheetState extends State<QuantityPadSheet> {
  late String _value = widget.initial.toString();

  void _input(String d) {
    setState(() {
      if (_value == '0') {
        _value = d;
      } else {
        _value += d;
        if (_value.length > 5) _value = _value.substring(0, 5);
      }
    });
  }

  void _clear() => setState(() => _value = '0');

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
              borderRadius: BorderRadius.circular(UiScale.scale(999)),
                ),
              ),
              // 10~30 快捷档位：点中即「设为 N」并关闭弹层
              for (final row in [
                [10, 11, 12, 13, 14, 15, 16],
                [17, 18, 19, 20, 21, 22, 23],
                [24, 25, 26, 27, 28, 29, 30],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _value,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              for (final row in [
                ['1', '2', '3'],
                ['4', '5', '6'],
                ['7', '8', '9'],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      for (final d in row)
                        Expanded(child: _PadKey(label: d, onTap: () => _input(d))),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(child: _PadKey(label: 'C', onTap: _clear)),
                    Expanded(child: _PadKey(label: '0', onTap: () => _input('0'))),
                    Expanded(
                      child: _PadKey(
                        icon: Icons.backspace_outlined,
                        onTap: () => setState(() {
                          _value = _value.length <= 1
                              ? '0'
                              : _value.substring(0, _value.length - 1);
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 60,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          '取消',
                          style: TextStyle(
                            fontSize: 20,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _ConfirmKey(
                      onTap: () =>
                          Navigator.pop(context, int.tryParse(_value) ?? 0),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 快捷档位小键：比数字键盘矮，按下轻缩放
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
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.92 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            height: UiScale.scale(44),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.button,
              borderRadius: BorderRadius.circular(UiScale.scale(12)),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: UiScale.scale(20),
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

class _PadKey extends StatefulWidget {
  const _PadKey({this.label, this.icon, required this.onTap});

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  State<_PadKey> createState() => _PadKeyState();
}

class _PadKeyState extends State<_PadKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
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
            child: widget.icon != null
                ? Icon(widget.icon,
                    size: UiScale.scale(26), color: AppColors.textPrimary)
                : Text(
                    widget.label!,
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

class _ConfirmKey extends StatefulWidget {
  const _ConfirmKey({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ConfirmKey> createState() => _ConfirmKeyState();
}

class _ConfirmKeyState extends State<_ConfirmKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            height: UiScale.scale(60),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.selected,
              borderRadius: BorderRadius.circular(UiScale.scale(16)),
            ),
            child: Text(
              '确定',
              style: TextStyle(
                fontSize: UiScale.scale(22),
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
