/// 商品领域模型（由 drift products 表读取）
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.priceCents,
    this.unit = '个',
    this.isActive = true,
    this.imagePath,
  });

  final int id;
  final String name;
  final int priceCents;
  final String unit;
  final bool isActive;

  /// 商品图片本地文件绝对路径；null 表示未设置
  final String? imagePath;
}
