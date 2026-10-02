import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/theme.dart';
import '../../features/cost/screens/cost_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/stats/screens/stats_screen.dart';

/// 低频操作全部收入抽屉，收银主界面不留入口、不使用底部 Tab。
/// 左上角 ☰ 或屏幕左缘右滑打开，点击遮罩关闭。
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * 0.82;
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: width.clamp(260.0, 360.0),
        child: Drawer(
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.zero,
              bottom: Radius.zero,
            ),
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _DrawerHeader(),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    children: [
                      _DrawerItem(
                        icon: Icons.bar_chart_rounded,
                        label: '统计',
                        page: const StatsScreen(),
                      ),
                      _DrawerItem(
                        icon: Icons.receipt_long_rounded,
                        label: '成本记录',
                        page: const CostScreen(),
                      ),
                      _DrawerItem(
                        icon: Icons.settings_outlined,
                        label: '设置',
                        page: const SettingsScreen(),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: _AppVersionLabel(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.selected.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(UiScale.scale(16)),
            ),
            child: const Icon(
              Icons.ramen_dining,
              color: AppColors.selected,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '和宝小吃',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '算价 · 记账 · 看经营',
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatefulWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.page,
  });

  final IconData icon;
  final String label;
  final Widget page;

  @override
  State<_DrawerItem> createState() => _DrawerItemState();
}

class _DrawerItemState extends State<_DrawerItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          Navigator.pop(context);
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => widget.page));
        },
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(UiScale.scale(14)),
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 24, color: AppColors.textPrimary),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 侧边栏底部版本号：运行时从 PackageInfo 读取（源头为 pubspec.yaml 的 version），
/// 展示为「和宝小吃 · vX.Y.Z」，避免硬编码与实际版本不一致。
class _AppVersionLabel extends StatefulWidget {
  const _AppVersionLabel();

  @override
  State<_AppVersionLabel> createState() => _AppVersionLabelState();
}

class _AppVersionLabelState extends State<_AppVersionLabel> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '和宝小吃 · v${_version ?? ''}',
      style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
    );
  }
}