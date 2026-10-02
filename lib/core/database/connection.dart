import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 返回 App 私有目录下的 SQLite 文件（完全离线，无网络）
LazyDatabase openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'hebao_pos.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
