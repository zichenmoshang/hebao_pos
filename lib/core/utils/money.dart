/// 金额一律以整数「分」存储，仅展示层格式化
String formatCents(int cents) {
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

/// 商品卡片单价：始终保留一位小数，如 ¥0.8/个、¥2.0/杯
String formatPriceCents(int cents) {
  final whole = cents ~/ 100;
  final remainder = cents % 100;
  final fraction = (remainder ~/ 10).toString();
  return '¥$whole.$fraction';
}
