import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    silenceDriftWarnings();
    await resetAppData();
  });

  Finder fieldByLabel(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );

  testWidgets('空数据导出提示、震动与常亮设置持久', (tester) async {
    await launchApp(tester);
    await openDrawerPage(tester, '设置');

    // 空区间导出 → 提示无可导出数据
    await tester.tap(find.text('导出数据'));
    await tester.pumpAndSettle();
    expect(find.text('选择导出区间'), findsOneWidget);
    await tester.tap(find.text('确定并导出'));
    await tester.pumpAndSettle();
    expect(find.text('所选区间暂无可导出的数据'), findsOneWidget);

    // 震动反馈默认开，点击关闭
    final hapticSwitch = find.byType(SwitchListTile);
    expect(tester.widget<SwitchListTile>(hapticSwitch).value, isTrue);
    await tester.tap(hapticSwitch);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(hapticSwitch).value, isFalse);

    // 屏幕常亮切换为 1 分钟
    await tester.tap(find.text('屏幕常亮'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 分钟'));
    await tester.pumpAndSettle();
    expect(find.text('1 分钟无操作后息屏'), findsOneWidget);

    // 离开重进：设置已持久化
    await goBack(tester); // → 收银
    await openDrawerPage(tester, '设置');
    expect(tester.widget<SwitchListTile>(hapticSwitch).value, isFalse);
    expect(find.text('1 分钟无操作后息屏'), findsOneWidget);
  });

  testWidgets('隐藏入口连点 6 次初始化数据，恢复默认商品', (tester) async {
    await launchApp(tester);

    // 先造数据：结一笔 + 新增一个商品
    await tester.tap(productCard('肉锅贴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('结账下一位'));
    await tester.pumpAndSettle();
    await openDrawerPage(tester, '设置');
    await tester.tap(find.text('商品管理'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新增商品'));
    await tester.pumpAndSettle();
    await enterTextAndSettle(tester, fieldByLabel('商品名称'), '茶叶蛋');
    await enterTextAndSettle(tester, fieldByLabel('单价（元）'), '2');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    await goBack(tester); // → 设置

    // 底部「和宝小吃」连点 6 次弹出确认
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.text('和宝小吃'));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text('初始化数据'), findsOneWidget);

    await tester.tap(find.text('确定初始化'));
    // 慢设备上初始化（清库 + 复制图片）耗时可能超过 snackbar 的 4 秒展示期，
    // 不能先 pumpAndSettle 再断言，改为轮询等待其出现
    await pumpUntilFound(tester, find.text('数据已初始化'));
    await tester.pumpAndSettle();

    // 回收银页：流水清零、恢复 6 个默认商品、自增商品消失
    await goBack(tester);
    expect(amountText('¥0.0'), findsOneWidget);
    expect(find.textContaining('今日 0 单', findRichText: true), findsOneWidget);
    for (final name in ['肉锅贴', '素锅贴', '豆浆', '豆腐脑', '五香蛋', '白粥']) {
      expect(find.text(name), findsOneWidget, reason: '默认商品 $name 未恢复');
    }
    expect(find.text('茶叶蛋'), findsNothing);

    // 模拟冷启动后仍是初始化后的干净状态
    await launchApp(tester);
    expect(find.textContaining('今日 0 单', findRichText: true), findsOneWidget);
    expect(find.text('茶叶蛋'), findsNothing);
  });
}
