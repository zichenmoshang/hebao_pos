import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hebao_pos/core/services/product_image_service.dart';

void main() {
  late ProductImageService service;
  late Directory tempDir;

  setUp(() {
    service = ProductImageService();
    tempDir = Directory.systemTemp.createTempSync('hebao_image_test');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('delete 传入 null 直接返回', () async {
    await service.delete(null);
  });

  test('delete 路径不存在时不抛异常', () async {
    await service.delete('${tempDir.path}/not_exists.jpg');
  });

  test('delete 删除已存在的文件', () async {
    final file = File('${tempDir.path}/product_1.jpg');
    await file.writeAsBytes([1, 2, 3]);
    expect(file.existsSync(), isTrue);

    await service.delete(file.path);
    expect(file.existsSync(), isFalse);
  });
}
