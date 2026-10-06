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

  /// 进入商品管理页
  Future<void> openProducts(WidgetTester tester) async {
    await openDrawerPage(tester, '设置');
    await tester.tap(find.text('商品管理'));
    await tester.pumpAndSettle();
    expect(find.text('商品管理'), findsWidgets);
  }

  /// 商品管理列表中某商品所在行的编辑/停用/启用按钮
  Finder tileIcon(String productName, IconData icon) => find.descendant(
        of: find.ancestor(
          of: find.text(productName),
          matching: find.byType(ListTile),
        ),
        matching: find.byIcon(icon),
      );

  Finder fieldByLabel(String label) => find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.labelText == label,
      );

  testWidgets('商品新增校验、重名拦截、编辑改价、停用启停', (tester) async {
    await launchApp(tester);
    await openProducts(tester);

    // 新增：空名称被拦截
    await tester.tap(find.text('新增商品'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请填写商品名称'), findsOneWidget);

    // 填名称未填单价被拦截
    await enterTextAndSettle(tester, fieldByLabel('商品名称'), '茶叶蛋');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('请填写正确的单价'), findsOneWidget);

    // 填单价后保存成功，列表出现
    await enterTextAndSettle(tester, fieldByLabel('单价（元）'), '2.5');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('茶叶蛋'), findsOneWidget);
    expect(find.text('¥2.5/个'), findsOneWidget);

    // 重名拦截
    await tester.tap(find.text('新增商品'));
    await tester.pumpAndSettle();
    await enterTextAndSettle(tester, fieldByLabel('商品名称'), '茶叶蛋');
    await enterTextAndSettle(tester, fieldByLabel('单价（元）'), '1');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('已存在同名商品'), findsOneWidget);
    await closeBottomSheet(tester);

    // 编辑改价为 ¥3（茶叶蛋在末行，先拖出 FAB 遮挡区再点行内按钮）
    await revealListEnd(tester, find.byType(ReorderableListView));
    await tester.tap(tileIcon('茶叶蛋', Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('编辑商品'), findsOneWidget);
    await enterTextAndSettle(tester, fieldByLabel('单价（元）'), '3');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(find.text('¥3/个'), findsOneWidget);

    // 回收银页：新商品已上网格，点按计价 ¥3
    await goBack(tester); // → 设置
    await goBack(tester); // → 收银
    expect(find.text('茶叶蛋'), findsOneWidget);
    await tester.tap(productCard('茶叶蛋'));
    await tester.pumpAndSettle();
    expect(amountText('¥3'), findsOneWidget);

    // 停用需二次确认，停用后网格消失（末行先拖出 FAB 遮挡区）
    await openProducts(tester);
    await revealListEnd(tester, find.byType(ReorderableListView));
    for (var attempt = 0; attempt < 3; attempt++) {
      await tester.tap(
        tileIcon('茶叶蛋', Icons.block_outlined),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      if (find.text('停用商品').evaluate().isNotEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    expect(find.text('停用商品'), findsOneWidget);
    await tester.tap(find.text('停用'));
    await tester.pumpAndSettle();
    expect(find.textContaining('（已停用）'), findsOneWidget);
    await goBack(tester);
    await goBack(tester);
    expect(find.text('茶叶蛋'), findsNothing);

    // 收银页仍保留停用前已点的茶叶蛋金额（内存订单不受影响）
    expect(amountText('¥3'), findsOneWidget);
  });

  testWidgets('全部停用时收银页空态，启用后恢复', (tester) async {
    await launchApp(tester);
    await openProducts(tester);

    // 停用全部 6 个种子商品（确认弹窗动画期间偶发遮挡，点按做有限重试）
    for (final name in ['肉锅贴', '素锅贴', '豆浆', '豆腐脑', '五香蛋', '白粥']) {
      if (name == '白粥') {
        // 末行操作按钮被 FAB 遮挡，先拖出遮挡区
        await revealListEnd(tester, find.byType(ReorderableListView));
      }
      for (var attempt = 0; attempt < 3; attempt++) {
        await tester.tap(
          tileIcon(name, Icons.block_outlined),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        if (find.text('停用商品').evaluate().isNotEmpty) break;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      expect(find.text('停用商品'), findsOneWidget);
      await tester.tap(find.text('停用'));
      await tester.pumpAndSettle();
    }

    // 收银页空态
    await goBack(tester);
    await goBack(tester);
    expect(find.text('暂无在售商品'), findsOneWidget);
    expect(find.text('肉锅贴'), findsNothing);

    // 启用肉锅贴后恢复
    await openProducts(tester);
    await tester.tap(tileIcon('肉锅贴', Icons.restore_outlined));
    await tester.pumpAndSettle();
    await goBack(tester);
    await goBack(tester);
    expect(find.text('肉锅贴'), findsOneWidget);
    expect(find.text('暂无在售商品'), findsNothing);
  });

  testWidgets('边界：单价允许 0 元（赠送类商品）', (tester) async {
    await launchApp(tester);
    await openProducts(tester);

    await tester.tap(find.text('新增商品'));
    await tester.pumpAndSettle();
    await enterTextAndSettle(tester, fieldByLabel('商品名称'), '免费咸菜');
    await enterTextAndSettle(tester, fieldByLabel('单价（元）'), '0');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    // 规则确认：0 元商品可保存并出现在列表（PRD 4.3 明确允许 0 元）
    expect(find.text('免费咸菜'), findsOneWidget);
    expect(find.text('¥0.0/个'), findsOneWidget);
  });
}
