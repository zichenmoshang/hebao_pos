# 数据库设计

数据库：SQLite，通过 drift 提供类型安全与迁移（已落地）。所有金额字段均为整数「**分**」，时间为 Unix 毫秒时间戳。

## 1. 表结构

### products（商品）

| 字段 | 类型 | 说明 |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | |
| name | TEXT NOT NULL | 商品名，如"肉锅贴" |
| price_cents | INTEGER NOT NULL | 单价（分），如 100 |
| unit | TEXT NOT NULL DEFAULT '个' | 单位：个/杯/碗 |
| image_path | TEXT | 商品图片本地文件绝对路径；NULL 表示未设置 |
| sort_index | INTEGER NOT NULL DEFAULT 0 | 主界面排序 |
| is_active | INTEGER NOT NULL DEFAULT 1 | 删除用软删除，保留历史订单引用 |
| created_at | INTEGER NOT NULL | |

### orders（订单 / 结账记录）

| 字段 | 类型 | 说明 |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | |
| total_cents | INTEGER NOT NULL | 订单总额（分），结账时快照 |
| created_at | INTEGER NOT NULL | 结账时间 |

### order_items（订单明细）

| 字段 | 类型 | 说明 |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | |
| order_id | INTEGER NOT NULL | 外键 → orders.id（级联删除） |
| product_id | INTEGER NOT NULL | 外键 → products.id |
| product_name | TEXT NOT NULL | 名称快照（商品后续改名不影响历史） |
| unit_price_cents | INTEGER NOT NULL | 成交单价快照（分） |
| quantity | INTEGER NOT NULL | 数量 |
| line_total_cents | INTEGER NOT NULL | 该行小计（分） |

### cost_categories（成本类目）

| 字段 | 类型 | 说明 |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | |
| name | TEXT NOT NULL UNIQUE | 如"猪肉""面粉""粉丝" |
| sort_index | INTEGER NOT NULL DEFAULT 0 | |
| is_active | INTEGER NOT NULL DEFAULT 1 | 软删除 |

### cost_records（原材料采购）

| 字段 | 类型 | 说明 |
|---|---|---|
| id | INTEGER PK AUTOINCREMENT | |
| category_id | INTEGER NOT NULL | 外键 → cost_categories.id |
| amount_cents | INTEGER NOT NULL | 采购金额（分） |
| occurred_on | INTEGER NOT NULL | 采购发生日期（当日 0 点时间戳，便于按日聚合） |
| note | TEXT | 选填备注 |
| created_at | INTEGER NOT NULL | |

### settings（设置键值，未使用）

当前已落地的业务表为 5 张：`products`、`orders`、`order_items`、`cost_categories`、`cost_records`（在 `AppDatabase` 注册，schemaVersion = 2）。设置项（震动、屏幕常亮）使用 `shared_preferences` 持久化，不进数据库。如未来希望统一进库与导出，再增加键值表：

| 字段 | 类型 | 说明 |
|---|---|---|
| key | TEXT PK | `haptic_enabled` / `screen_idle` 等 |
| value | TEXT NOT NULL | |

## 2. 索引

| 索引 | 字段 | 用途 |
|---|---|---|
| idx_orders_created_at | orders(created_at) | 按区间统计营业额/订单数 |
| idx_items_order_id | order_items(order_id) | 取单明细 |
| idx_items_product_id | order_items(product_id) | 单品销量聚合 |
| idx_cost_occurred_on | cost_records(occurred_on) | 区间成本聚合 |
| idx_cost_category | cost_records(category_id) | 成本类目分布 |

## 3. 典型查询

区间营业额与订单数：

```sql
SELECT COALESCE(SUM(total_cents), 0) AS amount,
       COUNT(*) AS orders
FROM orders
WHERE created_at >= :startMs AND created_at < :endMs;
```

区间单品销量与销售额：

```sql
SELECT product_id,
       product_name,
       SUM(quantity) AS qty,
       SUM(line_total_cents) AS amount
FROM order_items oi
JOIN orders o ON o.id = oi.order_id
WHERE o.created_at >= :startMs AND o.created_at < :endMs
GROUP BY product_id
ORDER BY amount DESC;
```

区间采购额（按类目）：

```sql
SELECT c.name, SUM(r.amount_cents) AS amount
FROM cost_records r
JOIN cost_categories c ON c.id = r.category_id
WHERE r.occurred_on >= :startDay AND r.occurred_on <= :endDay
GROUP BY c.id;
```

毛利估算：`区间营业额 − 区间采购额`。注意采购按发生日计入，非按实际消耗，仅作小店参考。

## 4. 结账写入（事务）

结账必须在单事务内写入 orders + 全部 order_items，保证总额与明细一致；成功后再清空内存订单。

## 5. 迁移策略

- schemaVersion 从 1 起，每次结构变更 +1；当前为 **2**
- 使用 drift `MigrationStrategy.onUpgrade` 提供增量迁移
  - v1 → v2：`products` 增加 `image_path` 列（`addColumn`）
- 历史数据只增不丢；商品/类目删除一律软删除（is_active）
- 软删除类目从新建选择列表隐藏，但其历史采购仍计入区间总额与类目分布（采购记录不做级联删除）
