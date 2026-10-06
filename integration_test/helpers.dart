import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/database/app_database.dart';
import 'package:hebao_pos/features/cashier/widgets/product_card.dart';
import 'package:hebao_pos/main.dart' as app;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 清空数据库 / 偏好设置 / 商品图片，保证用例间互不影响。
/// 每个用例启动 App 前调用；此时上一个 App 实例的连接即将随
/// runApp 替换根树而释放，独立连接清库不会与之争用。
Future<void> resetAppData() async {
  final db = AppDatabase();
  await db.clearAllData();
  await db.close();

  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();

  final dir = await getApplicationDocumentsDirectory();
  final imagesDir = Directory(p.join(dir.path, 'product_images'));
  if (await imagesDir.exists()) {
    await imagesDir.delete(recursive: true);
  }
}

/// 重新启动 App（替换整棵 widget 树，等价于冷启动）
Future<void> launchApp(WidgetTester tester) async {
  await app.main();
  await tester.pumpAndSettle();
}

/// 从收银页打开抽屉并进入指定页面
Future<void> openDrawerPage(WidgetTester tester, String label) async {
  await tester.tap(find.byIcon(Icons.menu));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// 关闭当前底部弹层（点击遮罩区）
Future<void> closeBottomSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(200, 60));
  await tester.pumpAndSettle();
}

/// 返回上一页（AppBar 返回按钮）
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
}

/// 弹层内数字键盘按键（限定在 BottomSheet 内，避开页面上的快捷数量键）
Finder padKey(String label) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.widgetWithText(GestureDetector, label),
    );

/// 收银页金额面板当前显示的金额（唯一的大字号金额文本）
Finder amountText(String amount) => find.text(amount);

/// 收银网格中的商品卡片（选中后快捷数量区也会显示商品名，需限定在卡片内）
Finder productCard(String name) => find.widgetWithText(ProductCard, name);

/// 输入文本并等待布局稳定。
/// 真机上 tester.enterText 依赖真实 IME 连接，收起键盘后二次输入会因
/// 连接重建竞态静默丢失；改为直接写 controller，并手动补发 onChanged
/// （程序化赋值不会触发字段的 onChanged，表单按钮态依赖它重算）。
/// 全程不弹系统键盘，也避免按钮被键盘遮挡导致 tap 落空。
Future<void> enterTextAndSettle(
  WidgetTester tester,
  Finder finder,
  String text,
) async {
  final field = tester.widget<TextField>(finder);
  field.controller!.text = text;
  field.onChanged?.call(text);
  await tester.pumpAndSettle();
}

/// 集成测试每个用例都会重建 AppDatabase（resetAppData），静默 drift 的多实例告警
void silenceDriftWarnings() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
}

/// 把列表向上拖一段，让被 FAB 遮挡的末行露出（FAB 区域固定约 72 逻辑像素）
Future<void> revealListEnd(WidgetTester tester, Finder listFinder) async {
  await tester.drag(listFinder, const Offset(0, -160));
  await tester.pumpAndSettle();
}
