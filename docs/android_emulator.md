# Android 模拟器调试指南

## 启动模拟器

1. 查看可用模拟器：

```bash
flutter emulators
```

2. 启动模拟器（`Nexus_5X_API_34` 替换为上一步列出的模拟器 id）：

```bash
flutter emulators --launch Nexus_5X_API_34
```

若列表为空，先用 Android Studio 的 Device Manager 创建一台模拟器（建议 Pixel 系、API 33+）。

3. 模拟器开机后确认已连接：

```bash
flutter devices
```

4. 运行 App；存在多个设备时用 `-d` 指定：

```bash
flutter run
flutter run -d emulator-5554
```

## `flutter run` 常用快捷键

| 按键 | 作用 |
|---|---|
| `r` | 热重载（UI 改动后生效，保留状态） |
| `R` | 热重启（重置状态） |
| `q` | 退出 |

## 多机型分辨率适配测试

通过 `adb shell wm` 在运行中的模拟器上临时调整分辨率与密度进行 UI 适配测试，详见 [android_device_testing.md](android_device_testing.md)。
