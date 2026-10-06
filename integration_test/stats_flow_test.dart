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

  /// 结一笔账：点指定商品 [taps] 次后结账
  Future<void> checkout(WidgetTester tester, String product, int taps) async {
    for (var i = 0; i < taps; i++) {
      await tester.tap(productCard(product));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('结账下一位'));
    await tester.pumpAndSettle();
  }

  /// 记一笔今天的手工采购（快速建类目并保存）
  Future<void> addCost(WidgetTester tester, String yuan) async {
    await openDrawerPage(tester, '成本记录');
    await tester.tap(find.text('记一笔'));
    await tester.pumpAndSettle();
    await enterTextAndSettle(
      tester,
      find.byWidgetPredicate(
        (w) => w is TextField && w.decoration?.hintText == '0.00',
      ),
      yuan,
    );
    await tester.tap(find.text('请选择类目'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建类目'));
    await tester.pumpAndSettle();
    await enterTextAndSettle(
      tester,
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '猪肉',
    );
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    // 快速新建后类目应回填到表单，保存按钮可用
    expect(find.text('猪肉'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, '记一笔'))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.widgetWithText(FilledButton, '记一笔'));
    await tester.pumpAndSettle();
    await goBack(tester); // → 收银
  }

  testWidgets('统计概览、单品排行、负毛利、删单联动', (tester) async {
    await launchApp(tester);

    // 结两笔：肉锅贴 ×2（¥3）、豆浆 ×1（¥2）
    await checkout(tester, '肉锅贴', 2);
    await checkout(tester, '豆浆', 1);

    // 统计页概览（营业额与毛利均为 ¥5：尚无成本录入）
    await openDrawerPage(tester, '统计');
    expect(find.text('¥5'), findsNWidgets(2));
    // 订单数卡的「2」与排行第 2 名徽标共存
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('¥2.5'), findsOneWidget); // 客单价

    // 单品排行：金额降序、占比
    expect(find.textContaining('销量 2'), findsOneWidget);
    expect(find.textContaining('占比 60%'), findsOneWidget);
    expect(find.textContaining('占比 40%'), findsOneWidget);

    // 展开排行第一行看每日销量（筛选栏日期 + 展开的当日销量行，共两处）
    await tester.tap(find.text('肉锅贴'));
    await tester.pumpAndSettle();
    final now = DateTime.now();
    expect(
      find.textContaining('${now.month}月${now.day}日'),
      findsNWidgets(2),
    );

    // 录入 ¥10.3 成本 → 毛利为负
    await goBack(tester); // → 收银
    await addCost(tester, '10.3');
    await openDrawerPage(tester, '统计');
    // 采购额卡 + 类目饼图图例同值出现
    expect(find.text('¥10.3'), findsWidgets);
    // 毛利 = 500 - 1030 = -530 分 → 应显示 ¥-5.3（回归：负金额曾错误显示 ¥-6.7）
    expect(find.text('¥-5.3'), findsOneWidget);
    // 毛利率 = -530/500 = -106.0%
    expect(find.text('-106.0%'), findsOneWidget);

    // 切「按月」出现趋势图，切回「按日」消失
    await tester.tap(find.text('按月'));
    await tester.pumpAndSettle();
    expect(find.text('按月'), findsOneWidget);
    await tester.tap(find.text('按日'));
    await tester.pumpAndSettle();

    // 区间订单明细：两笔（入口在长列表底部，先滚动露出）
    await tester.dragUntilVisible(
      find.text('区间订单明细'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('区间订单明细'));
    await tester.pumpAndSettle();
    expect(find.text('¥2'), findsOneWidget);
    expect(find.text('¥3'), findsOneWidget);

    // 滑动删除最新一笔（豆浆 ¥2）
    await tester.fling(find.text('¥2'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('删除该订单？'), findsOneWidget);
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('¥2'), findsNothing);

    // 展开剩余一笔查看明细
    await tester.tap(find.text('¥3'));
    await tester.pumpAndSettle();
    expect(find.text('肉锅贴 × 2'), findsOneWidget);

    // 回统计页：概览已重算（先滚回顶部，营业额与客单价均为 ¥3）
    await goBack(tester);
    await tester.drag(find.byType(ListView), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('¥3'), findsNWidgets(2));
    // 订单数卡的「1」与排行第 1 名徽标共存
    expect(find.text('1'), findsNWidgets(2));

    // 回收银页：今日流水应与统计一致（¥3）
    await goBack(tester);
    expect(find.textContaining('今日 1 单', findRichText: true), findsOneWidget);
    // 回归：删单后收银页今日流水曾显示旧值
    expect(find.textContaining('今日流水 ¥3', findRichText: true),
        findsOneWidget);
  });

  testWidgets('空区间：统计与订单明细均为空态', (tester) async {
    await launchApp(tester);
    await openDrawerPage(tester, '统计');

    expect(find.text('¥0.0'), findsWidgets); // 营业额
    expect(find.text('0'), findsOneWidget); // 订单数
    expect(find.text('该区间暂无销量'), findsOneWidget);
    // 营业额为 0 时毛利率无意义
    expect(find.text('—'), findsOneWidget);

    await tester.tap(find.text('区间订单明细'));
    await tester.pumpAndSettle();
    expect(find.text('该区间暂无订单'), findsOneWidget);
  });
}
