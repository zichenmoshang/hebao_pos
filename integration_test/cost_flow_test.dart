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

  final amountField = find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == '0.00',
  );
  final dialogField = find.descendant(
    of: find.byType(AlertDialog),
    matching: find.byType(TextField),
  );

  /// 类目选择弹层中新建类目（弹层自动关闭并选中）
  Future<void> createAndPickCategory(WidgetTester tester, String name) async {
    await tester.tap(find.text('新建类目'));
    await tester.pumpAndSettle();
    await enterTextAndSettle(tester, dialogField, name);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
  }

  testWidgets('记一笔：快速建类目、重名拦截、编辑、滑动删除', (tester) async {
    await launchApp(tester);
    await openDrawerPage(tester, '成本记录');

    // 空态 + 总额 ¥0.0
    expect(find.text('该区间暂无采购记录'), findsOneWidget);
    expect(find.text('¥0.0'), findsOneWidget);

    // 打开表单，先建类目
    await tester.tap(find.text('记一笔'));
    await tester.pumpAndSettle();
    expect(find.text('记一笔采购'), findsOneWidget);

    // 未选类目时保存按钮不可用
    await enterTextAndSettle(tester, amountField, '12.5');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '记一笔'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('请选择类目'));
    await tester.pumpAndSettle();
    expect(find.text('暂无类目，请先新建'), findsOneWidget);
    await createAndPickCategory(tester, '猪肉');

    // 重名类目被拦截并提示
    await tester.tap(find.text('猪肉'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建类目'));
    await tester.pumpAndSettle();
    await enterTextAndSettle(tester, dialogField, '猪肉');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('该类目已存在'), findsOneWidget);
    // 选择已有类目关闭弹层
    await tester.tap(find.widgetWithText(ListTile, '猪肉'));
    await tester.pumpAndSettle();

    // 填备注并保存
    await enterTextAndSettle(
      tester,
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '如：批发市场进货',
      ),
      '早市',
    );
    await tester.tap(find.widgetWithText(FilledButton, '记一笔'));
    await tester.pumpAndSettle();

    // 列表出现记录，总额卡与记录卡均为 ¥12.5
    expect(find.text('猪肉'), findsOneWidget);
    expect(find.text('早市'), findsOneWidget);
    expect(find.text('¥12.5'), findsNWidgets(2));

    // 编辑改金额为 ¥20
    await tester.tap(find.text('猪肉'));
    await tester.pumpAndSettle();
    expect(find.text('编辑采购'), findsOneWidget);
    await enterTextAndSettle(tester, amountField, '20');
    await tester.tap(find.widgetWithText(FilledButton, '保存'));
    await tester.pumpAndSettle();
    expect(find.text('¥20'), findsNWidgets(2));

    // 滑动删除 + 确认
    await tester.fling(find.text('猪肉'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('删除该笔采购？'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('该区间暂无采购记录'), findsOneWidget);
    expect(find.text('¥0.0'), findsOneWidget);
  });

  testWidgets('金额边界：0 / 多个小数点不可保存', (tester) async {
    await launchApp(tester);
    await openDrawerPage(tester, '成本记录');

    await tester.tap(find.text('记一笔'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('请选择类目'));
    await tester.pumpAndSettle();
    await createAndPickCategory(tester, '面粉');
    // 快速新建后类目应回填到表单
    expect(find.text('面粉'), findsOneWidget);

    final saveButton = find.widgetWithText(FilledButton, '记一笔');

    // 金额为 0 → 保存禁用
    await enterTextAndSettle(tester, amountField, '0');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    // 多个小数点无法解析 → 保存禁用
    await enterTextAndSettle(tester, amountField, '12.3.4');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNull);

    // 合法金额 → 可保存
    await enterTextAndSettle(tester, amountField, '8.8');
    expect(tester.widget<FilledButton>(saveButton).onPressed, isNotNull);
  });

  testWidgets('类目管理：新建、改名、软删后新建时不可选', (tester) async {
    await launchApp(tester);
    await openDrawerPage(tester, '成本记录');

    // 进入类目管理
    await tester.tap(find.byIcon(Icons.category_outlined));
    await tester.pumpAndSettle();
    expect(find.text('暂无类目，点击下方按钮新建'), findsOneWidget);

    // 新建
    await tester.tap(find.text('新建类目'));
    await tester.pumpAndSettle();
    await enterTextAndSettle(tester, dialogField, '牛肉');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('牛肉'), findsOneWidget);

    // 改名为羊肉
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await enterTextAndSettle(tester, dialogField, '羊肉');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('羊肉'), findsOneWidget);

    // 软删除
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('删除该类目？'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('已停用（历史记录保留）'), findsOneWidget);

    // 回成本记录：新建时类目选择列表不含已软删类目
    await goBack(tester);
    await tester.tap(find.text('记一笔'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('请选择类目'));
    await tester.pumpAndSettle();
    expect(find.text('暂无类目，请先新建'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '羊肉'), findsNothing);
  });
}
