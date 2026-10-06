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

  testWidgets('主流程：点选商品、快捷改量、结账落库、重启流水不丢', (tester) async {
    await launchApp(tester);

    // 首次启动播种 6 个商品，空单状态
    for (final name in ['肉锅贴', '素锅贴', '豆浆', '豆腐脑', '五香蛋', '白粥']) {
      expect(find.text(name), findsOneWidget, reason: '缺少商品 $name');
    }
    expect(amountText('¥0.0'), findsOneWidget);
    expect(find.textContaining('今日 0 单', findRichText: true), findsOneWidget);

    // 肉锅贴 ¥1.5/个，点两次 → ¥3
    await tester.tap(productCard('肉锅贴'));
    await tester.pump();
    await tester.tap(productCard('肉锅贴'));
    await tester.pumpAndSettle();
    expect(amountText('¥3'), findsOneWidget);

    // 快捷数量「设为 5」→ ¥7.5
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(amountText('¥7.5'), findsOneWidget);

    // 豆浆 ¥2.0/杯 点一次 → 合计 ¥9.5
    await tester.tap(productCard('豆浆'));
    await tester.pumpAndSettle();
    expect(amountText('¥9.5'), findsOneWidget);

    // 结账 → 订单清空、今日流水与单数更新
    await tester.tap(find.text('结账下一位'));
    await tester.pumpAndSettle();
    expect(amountText('¥0.0'), findsOneWidget);
    expect(find.textContaining('今日 1 单', findRichText: true), findsOneWidget);
    expect(find.textContaining('¥9.5', findRichText: true), findsOneWidget);

    // 模拟冷启动：流水来自数据库，重启不丢
    await launchApp(tester);
    expect(find.textContaining('今日 1 单', findRichText: true), findsOneWidget);
    expect(find.textContaining('¥9.5', findRichText: true), findsOneWidget);
  });

  testWidgets('分支：清除选中、整单清零、键盘大数量与边界输入', (tester) async {
    await launchApp(tester);

    // 素锅贴 ¥1.0/个 点两次 → 快捷「设为 3」→ ¥3
    await tester.tap(productCard('素锅贴'));
    await tester.pump();
    await tester.tap(productCard('素锅贴'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(amountText('¥3'), findsOneWidget);

    // 「清除」选中商品 → 空单，快捷区回引导文案
    await tester.tap(find.text('清除'));
    await tester.pumpAndSettle();
    expect(amountText('¥0.0'), findsOneWidget);
    expect(find.text('先点商品卡片'), findsOneWidget);

    // 白粥 ¥2.0/碗 → 「清零」整单清空
    await tester.tap(productCard('白粥'));
    await tester.pumpAndSettle();
    expect(amountText('¥2'), findsOneWidget);
    await tester.tap(find.text('清零'));
    await tester.pumpAndSettle();
    expect(amountText('¥0.0'), findsOneWidget);

    // 键盘弹层：豆腐脑 ¥3.0/碗，输入 12 → ¥36
    await tester.tap(productCard('豆腐脑'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    expect(find.text('确定'), findsOneWidget);
    await tester.tap(padKey('2')); // 初始 1 → 12
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(amountText('¥36'), findsOneWidget);

    // 边界：超过 5 位截断为 99999
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    await tester.tap(padKey('C'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.tap(padKey('9'));
      await tester.pump();
    }
    expect(find.text('99999'), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    // 99999 × ¥3 = ¥299997
    expect(amountText('¥299997'), findsOneWidget);

    // 键盘输入 0 → 移除该商品
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    await tester.tap(padKey('C'));
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(amountText('¥0.0'), findsOneWidget);

    // 空单时「结账下一位」不可用，不产生订单
    await tester.tap(find.text('结账下一位'));
    await tester.pumpAndSettle();
    expect(find.textContaining('今日 0 单', findRichText: true), findsOneWidget);
  });
}
