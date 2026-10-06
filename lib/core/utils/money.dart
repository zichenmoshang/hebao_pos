/// 金额一律以整数「分」存储，仅展示层格式化
String formatCents(int cents) {
  // 负数（如成本超过营业额的毛利）：~/ 向下取整会导致绝对值被放大，
  // 统一按绝对值格式化后补负号，保证 ¥-5.3 而非 ¥-6.7
  if (cents < 0) return '¥-${formatCents(-cents).substring(1)}';
  final whole = cents ~/ 100;
  final remainder = cents % 100;
  if (remainder == 0) {
    // 空单金额按原型弱化显示 ¥0.0
    return cents == 0 ? '¥0.0' : '¥$whole';
  }
  // 50 分显示一位小数，其余两位
  var fraction = remainder.toString().padLeft(2, '0');
  if (fraction.endsWith('0')) {
    fraction = fraction.substring(0, 1);
  }
  return '¥$whole.$fraction';
}

/// 商品卡片单价：始终保留一位小数，如 ¥0.8/个、¥2.0/杯。
/// 非整十分时四舍五入（255 分 → ¥2.6），与实际单价更贴近
String formatPriceCents(int cents) {
  final whole = cents ~/ 100;
  final roundedTenths = (cents / 10).round();
  final fraction = (roundedTenths % 10).toString();
  return '¥$whole.$fraction';
}
