import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/product.dart';

/// 商品大卡片：整块为点击区，上方临时占位图（后续在商品管理中上传实物图）、
/// 下方名称/单价；点击后数量 +1 并显示选中边框，数量 > 0 时底部变为青色带，
/// 右上角显示数量角标。
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.quantity,
    required this.selected,
    required this.onTap,
  });

  final Product product;
  final int quantity;
  final bool selected;
  final VoidCallback onTap;

  /// 临时占位图标，按商品 id 区分；上传实物图后移除
  static const _placeholderIcons = <int, IconData>{
    1: Icons.lunch_dining,
    2: Icons.ramen_dining,
    3: Icons.coffee,
    4: Icons.soup_kitchen,
    5: Icons.egg,
  };

  @override
  Widget build(BuildContext context) {
    final active = quantity > 0;
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        // 底层填充：圆角对齐物理像素
        painter: _CardFillPainter(
          radius: UiScale.snap(UiScale.scale(18)),
          color: AppColors.surface,
        ),
        // 前景描边：foregroundPainter 画在 child 之上；填充差集 + 物理像素对齐，
        // 避免 Impeller stroke 路径的圆角毛边
        foregroundPainter: _CardBorderPainter(
          radius: UiScale.snap(UiScale.scale(18)),
          color: selected ? AppColors.selected : AppColors.border,
          width: UiScale.snap(UiScale.scale(1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(UiScale.snap(UiScale.scale(18))),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 商品图片；未设置时显示占位（浅灰底 + 图标）
                    if (product.imagePath != null)
                      Image.file(
                        File(product.imagePath!),
                        fit: BoxFit.cover,
                      )
                    else
                      ColoredBox(
                        color: const Color(0xFFF2F1EE),
                        child: Icon(
                          _placeholderIcons[product.id] ?? Icons.restaurant,
                          size: UiScale.scale(64),
                          color: AppColors.textMuted,
                        ),
                      ),
                    if (active)
                      Positioned(
                        right: UiScale.scale(6),
                        top: UiScale.scale(6),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: UiScale.scale(8),
                            vertical: UiScale.scale(2),
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.selected,
                            borderRadius: BorderRadius.circular(
                              UiScale.scale(6),
                            ),
                          ),
                          child: Text(
                            '$quantity',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: UiScale.scale(14),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                height: UiScale.scale(58),
                color: active ? AppColors.activeBand : AppColors.surface,
                padding: EdgeInsets.symmetric(horizontal: UiScale.scale(6)),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        product.name,
                        style: TextStyle(
                          fontSize: UiScale.scale(20),
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    SizedBox(height: UiScale.scale(2)),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${formatPriceCents(product.priceCents)}/${product.unit}',
                        style: TextStyle(
                          fontSize: UiScale.scale(14),
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 卡片底层圆角填充
class _CardFillPainter extends CustomPainter {
  const _CardFillPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CardFillPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.color != color;
}

/// 卡片前景描边：用「外、内两个填充 RRect 的 evenOdd 差集」形成环形边框，
/// 替代 PaintingStyle.stroke——填充路径覆盖率计算更准，圆角更锐利；
/// width / radius 已在外部对齐到物理像素网格。
class _CardBorderPainter extends CustomPainter {
  const _CardBorderPainter({
    required this.radius,
    required this.color,
    required this.width,
  });

  final double radius;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final innerRadius = (radius - width).clamp(0.0, radius);
    final outer = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        width,
        width,
        size.width - width * 2,
        size.height - width * 2,
      ),
      Radius.circular(innerRadius),
    );
    final path = Path()
      ..addRRect(outer)
      ..addRRect(inner)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _CardBorderPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.color != color ||
      oldDelegate.width != width;
}
