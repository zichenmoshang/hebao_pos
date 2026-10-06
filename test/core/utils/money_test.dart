import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/utils/money.dart';

void main() {
  group('formatCents', () {
    test('空单金额弱化显示一位小数', () {
      expect(formatCents(0), '¥0.0');
    });

    test('整元不带小数', () {
      expect(formatCents(100), '¥1');
      expect(formatCents(200), '¥2');
    });

    test('整角显示一位小数', () {
      expect(formatCents(80), '¥0.8');
      expect(formatCents(150), '¥1.5');
      expect(formatCents(250), '¥2.5');
    });

    test('带分显示两位小数', () {
      expect(formatCents(205), '¥2.05');
      expect(formatCents(1234), '¥12.34');
    });

    test('负金额按绝对值格式化后补负号（毛利为负场景）', () {
      expect(formatCents(-500), '¥-5');
      expect(formatCents(-530), '¥-5.3');
      expect(formatCents(-1050), '¥-10.5');
      expect(formatCents(-1234), '¥-12.34');
    });
  });

  group('formatPriceCents', () {
    test('单价始终保留一位小数', () {
      expect(formatPriceCents(80), '¥0.8');
      expect(formatPriceCents(200), '¥2.0');
      expect(formatPriceCents(250), '¥2.5');
      expect(formatPriceCents(1234), '¥12.3');
    });

    test('非整十分四舍五入', () {
      expect(formatPriceCents(255), '¥2.6');
      expect(formatPriceCents(254), '¥2.5');
    });
  });
}
