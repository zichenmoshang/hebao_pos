# 贡献指南

感谢参与和宝小吃（hebao_pos）！

## 开发环境

- Flutter stable 频道
- `flutter doctor` 无错误
- 克隆后执行 `flutter pub get`

## 提交流程

1. Fork 并从 `main` 切出分支，命名如 `feat/cashier-keypad`、`fix/stats-range`
2. 提交前请确保：
   - `flutter analyze` 无告警
   - `flutter test` 通过，并为新逻辑补充测试
3. 提交信息使用约定式格式：
   - `feat: 新功能`
   - `fix: 修复`
   - `docs: 文档`
   - `refactor: 重构`
   - `test: 测试`
   - `chore: 杂项`
4. 涉及需求或架构变更时，同步更新 `docs/` 下对应文档
5. 发起 PR，并在描述中说明动机、方案与测试方式

## 代码约定

- 遵循 feature-first 分层：`features` 之间不互相引用，共享内容下沉到 `shared` / `core`
- 依赖方向：UI → repository → database，不允许反向依赖
- 金额一律使用整数「分」存储，禁止用浮点表示价格
- 新增大段逻辑请补充单元测试，关键页面补充 widget 测试

## 发布版本（仅维护者）

1. 更新 [pubspec.yaml](pubspec.yaml) 的 `version` 与 [CHANGELOG.md](CHANGELOG.md)
2. 提交并合并到 `main` 后打 tag（tag 名以 `v` 开头，与 version 一致）：

```bash
git tag v1.0.0
git push origin v1.0.0
```

3. [release.yml](.github/workflows/release.yml) 工作流自动按 ABI 分包构建 APK、生成 SHA256 校验文件并创建 GitHub Release（Release Notes 由合并的 PR / 提交自动生成）
4. 若需正式签名，在仓库 Settings → Secrets and variables → Actions 配置 `ANDROID_KEYSTORE_BASE64`、`KEY_ALIAS`、`STORE_PASSWORD`、`KEY_PASSWORD`；未配置时使用 debug 签名

## 行为准则

保持友善、就事论事，欢迎所有水平的参与者。
