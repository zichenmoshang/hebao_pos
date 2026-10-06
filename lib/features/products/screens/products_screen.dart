import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/providers/active_products_provider.dart';
import '../../../core/repositories/product_repository.dart';
import '../../../core/utils/money.dart';
import '../../../shared/models/product.dart';
import '../providers/products_provider.dart';
import '../widgets/product_form.dart';

/// 商品管理：拖拽排序 + 新增 / 编辑 / 停用 / 启用
class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  void _refresh(WidgetRef ref) {
    ref.invalidate(allProductsProvider);
    // 收银网格商品也需刷新
    ref.invalidate(activeProductsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    UiScale.init(context);
    final productsAsync = ref.watch(allProductsProvider);
    final pad = UiScale.scale(12);

    return Scaffold(
      appBar: AppBar(title: const Text('商品管理')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await ProductForm.show(context);
          if (saved == true) _refresh(ref);
        },
        icon: const Icon(Icons.add),
        label: const Text('新增商品'),
      ),
      body: SafeArea(
        child: productsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('读取失败：$e')),
          data: (products) {
            if (products.isEmpty) {
              return Center(
                child: Text(
                  '暂无商品，点击下方按钮新增',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              );
            }
            return ReorderableListView.builder(
              padding: EdgeInsets.fromLTRB(
                pad,
                pad,
                pad,
                // FAB 高 56 + 下边距 16 不随 UiScale 缩放，小屏下
                // 缩放过的 padding 可能小于 FAB 区域导致末行按钮被遮挡
                88,
              ),
              itemCount: products.length,
              buildDefaultDragHandles: false,
              onReorderItem: (oldIndex, newIndex) async {
                final list = [...products];
                final item = list.removeAt(oldIndex);
                list.insert(newIndex, item);
                await ref.read(productRepositoryProvider).reorder(list);
                _refresh(ref);
              },
              itemBuilder: (context, i) {
                final product = products[i];
                return _ProductTile(
                  key: ValueKey('product-${product.id}'),
                  product: product,
                  index: i,
                  ref: ref,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    super.key,
    required this.product,
    required this.index,
    required this.ref,
  });

  final Product product;
  final int index;
  final WidgetRef ref;

  Future<void> _edit(BuildContext context) async {
    final saved = await ProductForm.show(context, product: product);
    if (saved == true) {
      ref.invalidate(allProductsProvider);
      // 收银网格常驻监听，改价/改名后需同步刷新
      ref.invalidate(activeProductsProvider);
    }
  }

  Future<void> _toggleActive(BuildContext context) async {
    final activating = !product.isActive;
    // 停用需二次确认，启用直接执行
    if (!activating) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('停用商品'),
          content: Text('确定停用「${product.name}」吗？\n停用后将从收银网格消失，可随时重新启用。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('停用'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref.read(productRepositoryProvider).setActive(product.id, activating);
    ref.invalidate(allProductsProvider);
    // 收银网格常驻监听，停用/启用后需同步刷新
    ref.invalidate(activeProductsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pad = UiScale.scale(8);

    final content = Container(
      margin: EdgeInsets.only(bottom: pad),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(UiScale.scale(14)),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: _Thumbnail(product: product),
        title: Text(
          product.name,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: product.isActive
                ? AppColors.textPrimary
                : AppColors.textMuted,
            decoration:
                product.isActive ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Text(
          '${formatCents(product.priceCents)}/${product.unit}'
          '${product.isActive ? '' : '（已停用）'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle_rounded,
                  color: AppColors.textMuted),
            ),
            IconButton(
              tooltip: '编辑',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _edit(context),
            ),
            IconButton(
              tooltip: product.isActive ? '停用' : '启用',
              icon: Icon(
                product.isActive
                    ? Icons.block_outlined
                    : Icons.restore_outlined,
                color: product.isActive
                    ? AppColors.danger
                    : AppColors.selected,
              ),
              onPressed: () => _toggleActive(context),
            ),
          ],
        ),
      ),
    );

    return content;
  }
}

/// 列表项左侧商品缩略图；无图显示名称首字占位
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final size = UiScale.scale(46);
    if (product.imagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(UiScale.scale(10)),
        child: Image.file(
          File(product.imagePath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _namePlaceholder(size, product),
        ),
      );
    }
    return _namePlaceholder(size, product);
  }

  Widget _namePlaceholder(double size, Product product) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F1EE),
        borderRadius: BorderRadius.circular(UiScale.scale(10)),
      ),
      child: Text(
        product.name.isNotEmpty ? product.name.characters.first : '?',
        style: TextStyle(
          fontSize: UiScale.scale(18),
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}
