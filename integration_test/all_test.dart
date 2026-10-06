import 'cashier_flow_test.dart' as cashier_flow;
import 'cost_flow_test.dart' as cost_flow;
import 'products_manage_test.dart' as products_manage;
import 'settings_flow_test.dart' as settings_flow;
import 'stats_flow_test.dart' as stats_flow;

/// 聚合入口：一次构建跑全部集成用例。
/// CI（release.yml 发版门禁）直接执行本文件，避免每个测试文件
/// 各自触发一次 APK 构建（约省 5 分钟）；各用例文件仍保留独立
/// main，本地调试可单独执行。
void main() {
  cashier_flow.main();
  cost_flow.main();
  products_manage.main();
  settings_flow.main();
  stats_flow.main();
}
