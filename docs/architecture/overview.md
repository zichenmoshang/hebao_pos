# 架构总览

## 1. 技术选型

| 项 | 选型 | 理由 |
|---|---|---|
| 框架 | Flutter | 自绘 UI，密集大按钮点击反馈稳定；屏幕常亮、开机直达等原生能力成熟；本应用更新频率低，无需跨端/热更新 |
| 平台 | 仅 Android | 店内专用安卓机 + 支架全天常开 |
| 语言 | Dart | Flutter 官方语言 |
| 状态管理 | Riverpod | 编译时安全、可测试、样板代码少，适合本项目规模 |
| 本地数据库 | SQLite（drift） | 订单与成本需按任意日期区间聚合，关系型 + SQL 最直接；drift 提供类型安全与迁移 |
| 架构分层 | feature-first | 按功能域隔离，共享内容下沉 |

候选对比：RN/Expo 的热更新在本低频更新场景价值有限；小程序受微信容器约束、启动路径长、本地存储容量受限，不适合全天常开与长期数据，故排除。

## 2. 目录结构

```text
lib/
├── main.dart                 # 入口：ProviderScope
├── app/                      # 应用级配置
│   ├── app.dart              # MaterialApp、主题、本地化
│   └── theme.dart
├── core/                     # 基础设施（业务无关）
│   ├── database/             # 数据库、表、迁移（连接惰性打开）
│   ├── repositories/         # order_repository、product_repository、cost_repository
│   ├── providers/            # activeProductsProvider（在售商品，跨功能共享）
│   ├── services/             # 商品图片服务、Excel 导出服务
│   ├── settings/             # 设置 provider、屏幕常亮控制器
│   └── utils/                # 金额(分)、日期区间、震动
├── features/                 # 功能域，互不直接引用
│   ├── cashier/
│   │   ├── screens/
│   │   ├── widgets/          # 商品卡片、快捷数量区、数字键盘、结账栏
│   │   └── providers/        # 当前订单状态、当日流水
│   ├── stats/
│   │   ├── screens/          # 统计页、区间订单明细
│   │   ├── widgets/          # 概览、折线图、单品排行、成本毛利行、类目环形图
│   │   └── providers/        # 时间筛选、销售与成本聚合
│   ├── cost/
│   │   ├── screens/          # 成本记录页、类目管理
│   │   ├── widgets/          # 时间筛选栏、记录/编辑表单
│   │   └── providers/        # 时间筛选、类目、区间总额与流水
│   ├── products/
│   │   ├── screens/          # 商品管理（拖拽排序、停用/启用）
│   │   ├── widgets/          # 新增/编辑表单
│   │   └── providers/        # 全部商品（含停用）
│   └── settings/
│       ├── screens/          # 设置页
│       └── widgets/          # 屏幕常亮选择
└── shared/                   # 跨功能共享
    ├── widgets/              # AppDrawer、AppToast、日期选择弹窗、通用按钮
    └── models/               # Product 等
```

打包资源（`pubspec.yaml` 已注册商品图目录）：

```text
assets/
├── branding/                 # 品牌源图（不入包运行时引用，供图标/启动屏生成）
│   ├── app_icon.png          # 启动器方形象征图
│   ├── app_icon_foreground.png # Android 自适应图标前景（留白）
│   └── splash_logo.png       # 启动屏 logo
└── images/products/          # 5 个默认商品内置图（随包打入）
    └── rou_guotie.jpg ...
```

数据库在首次访问 `appDatabaseProvider`（Riverpod `Provider<AppDatabase>`）时惰性打开，应用生命周期内复用，无需在 `main()` 中显式初始化。

`test/` 目录镜像 `lib/` 结构。

## 3. 分层与依赖规则

依赖方向严格单向：

```text
UI (screens/widgets)
        │
        ▼
providers (Riverpod)
        │
        ▼
repositories
        │
        ▼
database (DAO / SQLite)
```

规则：

1. `features/*` 之间**禁止互相 import**；需要共享时下沉到 `shared/` 或 `core/`
2. UI 不直接操作数据库，统一经 repository
3. repository 对上层暴露领域模型，隐藏 SQL 细节
4. 金额一律使用整数「分」，禁止 `double` 表示价格，避免浮点误差

## 4. 运行时数据流（收银 / 成本）

1. 收银页访问 `activeProductsProvider` → 经 repository 惰性打开数据库（首次启动写入 5 个商品种子）→ 加载在售商品列表
2. 收银页通过该 provider 渲染商品网格（上图下文；无图显示占位）
3. 点击商品 → `currentOrderNotifier` 修改内存中订单行（商品 id、数量、堂食/打包通道）
4. 金额面板监听订单状态，实时聚合总价（零延迟）
5. 结账 → `orderRepository` 在一个事务内写入 `orders` 与 `order_items` → 清空内存订单 → 当日流水 invalidate 重算
6. 商品管理经 `productRepository` 维护商品（新增 / 改名 / 改价 / 改单位 / 停用启用 / 拖拽重排）；图片经 `ProductImageService` 拍照或相册选取、压缩后存应用文档目录，数据库仅存路径；抽屉关闭（`onDrawerChanged`）时收银页 invalidate 商品与流水
7. 成本页经 `costRepository` 维护类目（新增 / 改名 / 软删除）与采购记录（增 / 改 / 删），区间总额与流水 invalidate 重算
8. 统计页经 repository 对历史订单与采购做聚合：销售指标、每日趋势、单品排行、采购类目分布，毛利 = 区间营业额 − 区间采购额
9. 设置经 `shared_preferences` 持久化（震动、屏幕常亮）；Excel 导出由 `CsvExportService` 生成单文件多工作表并经 `share_plus` 分享

当前订单（未结账）只存内存，不落库；如需防进程被杀丢失，可在 P1 评估本地草稿。

## 5. 关键设计约定

- **金额单位**：数据库、模型全部用「分」整数；仅在展示层格式化为 `¥12.5`
- **时间**：统一存本地时间戳；统计按设备本地日期切分（单店无时区问题）
- **数据库迁移**：schema 变更必须递增版本并提供 migration，禁止删库重建
- **商品图片**：完全离线，压缩后存应用文档目录 `product_images/`，数据库仅存文件路径；换图删旧文件，停用保留图片。默认 5 个商品的内置图随包打入 assets，`ensureSeeded()` 播种时复制到应用目录，使种子图与用户拍照路径形态一致
- **品牌资源**：图标源图在 `assets/branding/`，用 `flutter_launcher_icons`（配置 `flutter_launcher_icons.yaml`）生成 mipmap 与自适应图标；启动屏为 `android/app/src/main/res` 下的标准 drawable/styles 资源（含 v31 Android 12 图），不依赖运行时插件
- **商品网格滚动**：1～2 排时卡片高度精确适配可用空间、不滚动；3 排及以上用固定宽高比并可滚动
- **屏幕常亮 / 震动**：通过对应插件在收银页生命周期内启用，设置项持久化

## 6. 测试策略

| 层 | 测试 |
|---|---|
| core/utils | 单元测试：金额换算、日期区间 |
| repositories | 对内存/临时 SQLite 验证写入与聚合 |
| providers | 状态变更：加一、设数量、结账清空 |
| 关键 widgets | widget 测试：点按 → 数量/总价更新 |

## 7. 开源工程约定

- PR 需通过 `flutter analyze` 与 `flutter test`
- 提交信息遵循 Conventional Commits（见 CONTRIBUTING）
- 需求 / 架构变更随 PR 更新 `docs/`
