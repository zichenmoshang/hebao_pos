import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_database.dart';

/// 全局唯一的 Drift 数据库实例。
/// 应用生命周期内复用，连接在首次访问时惰性打开。
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
