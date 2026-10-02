import 'dart:io';

import 'package:excel/excel.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../database/app_database_provider.dart';
import '../repositories/cost_repository.dart';
import '../repositories/order_repository.dart';
import '../utils/date_range.dart';

/// 区间内无任何可导出数据
class ExportEmptyException implements Exception {
  const ExportEmptyException();
}

/// 数据导出：按区间生成单个 xlsx，含「订单汇总 / 订单明细 / 成本采购」三个工作表
class CsvExportService {
  CsvExportService(this._ref);

  final Ref _ref;

  Future<void> export(
      DateRange range, DateTime startDay, DateTime endDay) async {
    final orders =
        await _ref.read(orderRepositoryProvider).ordersInRange(range);
    final costs = await _ref.read(costRepositoryProvider).recordsInRange(range);

    // 列表为时间倒序，导出统一改为正序
    final orderedOrders = orders.reversed.toList();
    final orderedCosts = costs.reversed.toList();
    if (orderedOrders.isEmpty && orderedCosts.isEmpty) {
      throw const ExportEmptyException();
    }

    final excel = Excel.createExcel();
    // 默认工作簿名为 Sheet1，先写入再删除，保证只保留三个目标 sheet
    excel.rename(excel.tables.keys.first, '订单汇总');
    final summarySheet = excel['订单汇总'];
    final detailSheet = excel['订单明细'];
    final costSheet = excel['成本采购'];

    summarySheet.appendRow([
      for (final h in ['订单号', '下单时间', '总额(元)']) TextCellValue(h),
    ]);
    detailSheet.appendRow([
      for (final h in ['订单号', '商品名', '单价(元)', '数量', '行小计(元)'])
        TextCellValue(h),
    ]);
    costSheet.appendRow([
      for (final h in ['日期', '类目', '金额(元)', '备注']) TextCellValue(h),
    ]);

    // 一次批量取全部订单明细，再按 orderId 分组（消除 N+1）
    final allItems = await _ref
        .read(orderRepositoryProvider)
        .itemsOfOrders([for (final o in orderedOrders) o.id]);
    final itemsByOrder = <int, List<OrderItemDetail>>{};
    for (final item in allItems) {
      (itemsByOrder[item.orderId] ??= []).add(item);
    }

    for (final order in orderedOrders) {
      summarySheet.appendRow([
        IntCellValue(order.id),
        TextCellValue(
            DateFormat('yyyy-MM-dd HH:mm:ss').format(order.createdAt)),
        DoubleCellValue(_yuan(order.totalCents)),
      ]);

      for (final it in itemsByOrder[order.id] ?? const <OrderItemDetail>[]) {
        detailSheet.appendRow([
          IntCellValue(order.id),
          TextCellValue(it.productName),
          DoubleCellValue(_yuan(it.unitPriceCents)),
          IntCellValue(it.quantity),
          DoubleCellValue(_yuan(it.lineTotalCents)),
        ]);
      }
    }

    for (final c in orderedCosts) {
      costSheet.appendRow([
        TextCellValue(DateFormat('yyyy-MM-dd').format(c.occurredOn)),
        TextCellValue(c.categoryName),
        DoubleCellValue(_yuan(c.amountCents)),
        TextCellValue(c.note ?? ''),
      ]);
    }

    // 无订单时删除两个空 sheet；无成本时删除成本 sheet，避免留下只有表头的页
    if (orderedOrders.isEmpty) {
      excel.delete('订单汇总');
      excel.delete('订单明细');
    }
    if (orderedCosts.isEmpty) {
      excel.delete('成本采购');
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw const ExportEmptyException();
    }

    final dir = await getTemporaryDirectory();
    final tag =
        '${DateFormat('yyyyMMdd').format(startDay)}-${DateFormat('yyyyMMdd').format(endDay)}';
    final file = File(p.join(dir.path, '经营数据_$tag.xlsx'));
    await file.writeAsBytes(bytes, flush: true);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: '经营数据导出 $tag',
        text: '区间 ${DateFormat('yyyy-MM-dd').format(startDay)} ~ '
            '${DateFormat('yyyy-MM-dd').format(endDay)} 的经营数据',
      ),
    );
  }

  /// 分 -> 元
  double _yuan(int cents) => cents / 100;
}

final csvExportServiceProvider = Provider<CsvExportService>((ref) {
  ref.watch(appDatabaseProvider);
  return CsvExportService(ref);
});
