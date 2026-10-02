import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 商品图片来源
enum ProductImageSource { camera, gallery }

/// 商品图片服务：拍照 / 相册选取 → 压缩 → 存为应用文档目录下本地文件。
/// 完全离线，数据库仅保存返回的文件路径。
class ProductImageService {
  final _picker = ImagePicker();

  /// 选取并保存图片，返回本地文件绝对路径；用户取消返回 null
  Future<String?> pickAndSave(ProductImageSource source) async {
    final picked = await _picker.pickImage(
      source: source == ProductImageSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 90,
    );
    if (picked == null) return null;

    // 压缩为较小尺寸，收银网格无需高分辨率
    final bytes = await FlutterImageCompress.compressWithFile(
      picked.path,
      minWidth: 600,
      minHeight: 600,
      quality: 80,
    );
    if (bytes == null || bytes.isEmpty) return null;

    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(dir.path, 'product_images'));
    if (!imagesDir.existsSync()) {
      imagesDir.createSync(recursive: true);
    }

    final fileName =
        'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final file = File(p.join(imagesDir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// 删除指定图片文件（更换图片或移除图片时调用）
  Future<void> delete(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
