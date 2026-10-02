import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/repositories/product_repository.dart';
import '../../../core/services/product_image_service.dart';
import '../../../shared/models/product.dart';

/// 单位固定选项 + 自定义
const _presetUnits = ['个', '杯', '碗', '瓶', '份'];

/// 新增 / 编辑商品表单
class ProductForm extends ConsumerStatefulWidget {
  const ProductForm({super.key, this.product});

  /// 为 null 表示新增
  final Product? product;

  /// 返回 true 表示保存成功
  static Future<bool?> show(BuildContext context, {Product? product}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UiScale.scale(18)),
        ),
      ),
      builder: (_) => ProductForm(product: product),
    );
  }

  @override
  ConsumerState<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends ConsumerState<ProductForm> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();

  bool _customUnit = false;
  String _unit = '个';
  String? _imagePath;
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  final _imageService = ProductImageService();

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _nameCtrl.text = p.name;
      _priceCtrl.text = (p.priceCents / 100).toStringAsFixed(2);
      _imagePath = p.imagePath;
      if (_presetUnits.contains(p.unit)) {
        _unit = p.unit;
      } else {
        _customUnit = true;
        _unitCtrl.text = p.unit;
      }
    }
  }

  Future<void> _pickImage(ProductImageSource source) async {
    final path = await _imageService.pickAndSave(source);
    if (path == null) return;
    final oldPath = _imagePath;
    setState(() => _imagePath = path);
    // 换新图后删除旧文件
    if (oldPath != null && oldPath != path) {
      await _imageService.delete(oldPath);
    }
  }

  Future<void> _showImageSourceSheet() async {
    final source = await showModalBottomSheet<ProductImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(UiScale.scale(18)),
        ),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('拍照'),
              onTap: () => Navigator.of(context)
                  .pop(ProductImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('从相册选择'),
              onTap: () => Navigator.of(context)
                  .pop(ProductImageSource.gallery),
            ),
            SizedBox(height: UiScale.scale(8)),
          ],
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _removeImage() async {
    final oldPath = _imagePath;
    setState(() => _imagePath = null);
    await _imageService.delete(oldPath);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  int? _parsePriceCents() {
    final text = _priceCtrl.text.trim();
    final value = double.tryParse(text);
    if (value == null || value < 0) return null;
    return (value * 100).round();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final priceCents = _parsePriceCents();
    final unit = _customUnit ? _unitCtrl.text.trim() : _unit;

    setState(() => _error = null);

    if (name.isEmpty) {
      setState(() => _error = '请填写商品名称');
      return;
    }
    if (priceCents == null) {
      setState(() => _error = '请填写正确的单价');
      return;
    }
    if (unit.isEmpty) {
      setState(() => _error = '请填写单位');
      return;
    }

    final repo = ref.read(productRepositoryProvider);
    if (await repo.nameExists(name, excludeId: _isEdit ? widget.product!.id : null)) {
      if (!mounted) return;
      setState(() => _error = '已存在同名商品');
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await repo.updateProduct(
          id: widget.product!.id,
          name: name,
          priceCents: priceCents,
          unit: unit,
          imagePath: _imagePath,
        );
      } else {
        await repo.add(
          name: name,
          priceCents: priceCents,
          unit: unit,
          imagePath: _imagePath,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    UiScale.init(context);
    final pad = UiScale.scale(14);

    return Padding(
      padding: EdgeInsets.only(
        left: pad,
        right: pad,
        top: pad,
        bottom: MediaQuery.of(context).viewInsets.bottom + pad,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isEdit ? '编辑商品' : '新增商品',
            style: TextStyle(
              fontSize: UiScale.scale(18),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: pad),
          _ImagePicker(
            imagePath: _imagePath,
            name: _nameCtrl.text,
            onTap: _showImageSourceSheet,
            onRemove: _removeImage,
          ),
          SizedBox(height: pad),
          TextField(
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: '商品名称',
              hintText: '如：肉锅贴',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: pad),
          TextField(
            controller: _priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: const InputDecoration(
              labelText: '单价（元）',
              hintText: '如：0.8',
              border: OutlineInputBorder(),
            ),
          ),
          SizedBox(height: pad),
          Text(
            '单位',
            style: TextStyle(
              fontSize: UiScale.scale(14),
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: UiScale.scale(8)),
          Wrap(
            spacing: UiScale.scale(8),
            runSpacing: UiScale.scale(8),
            children: [
              for (final u in _presetUnits)
                _UnitChip(
                  label: u,
                  selected: !_customUnit && _unit == u,
                  onTap: () => setState(() {
                    _customUnit = false;
                    _unit = u;
                  }),
                ),
              _UnitChip(
                label: '自定义',
                selected: _customUnit,
                onTap: () => setState(() => _customUnit = true),
              ),
            ],
          ),
          if (_customUnit) ...[
            SizedBox(height: pad),
            TextField(
              controller: _unitCtrl,
              decoration: const InputDecoration(
                labelText: '自定义单位',
                hintText: '如：笼、串',
                border: OutlineInputBorder(),
              ),
            ),
          ],
          if (_error != null) ...[
            SizedBox(height: pad),
            Text(
              _error!,
              style: TextStyle(
                color: AppColors.danger,
                fontSize: UiScale.scale(14),
              ),
            ),
          ],
          SizedBox(height: UiScale.scale(18)),
          SizedBox(
            height: UiScale.scale(50),
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitChip extends StatelessWidget {
  const _UnitChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: UiScale.scale(16),
          vertical: UiScale.scale(9),
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.selected : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(UiScale.scale(20)),
          border: Border.all(
            color: selected ? AppColors.selected : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: UiScale.scale(14),
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// 商品图片选择区：有图显示缩略图（可移除），无图显示虚线占位
class _ImagePicker extends StatelessWidget {
  const _ImagePicker({
    required this.imagePath,
    required this.name,
    required this.onTap,
    required this.onRemove,
  });

  final String? imagePath;
  final String name;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final size = UiScale.scale(96);

    Widget content;
    if (imagePath != null) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(UiScale.scale(12)),
            child: Image.file(
              File(imagePath!),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            right: -8,
            top: -8,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      );
    } else {
      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(UiScale.scale(12)),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined,
                color: AppColors.textMuted),
            SizedBox(height: UiScale.scale(6)),
            Text(
              '添加图片',
              style: TextStyle(
                fontSize: UiScale.scale(12),
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(onTap: onTap, child: content);
  }
}
