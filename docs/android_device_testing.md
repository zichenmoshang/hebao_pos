# Android 模拟器机型分辨率测试

通过 `adb shell wm` 命令在运行中的模拟器上临时调整分辨率与屏幕密度，用于 UI 适配测试。

## 基本原理

- `wm size` 设置的是**物理像素**（宽×高）。
- `wm density` 设置的是 **DPI（屏幕密度）**。
- 逻辑宽度（dp）= 物理宽度 ÷ (density / 160)。
- 主流手机逻辑宽度大多为 **360dp** 或 **411dp**；测试排版时应重点关注逻辑宽度，而非物理分辨率。

## 手机机型（竖屏，宽×高）

| 机型参考 | size | density | 逻辑宽度 |
|---|---|---|---|
| 老旧/小屏机（720p） | `720x1280` | `320` | 360dp |
| 经典 1080p（16:9） | `1080x1920` | `480` | 360dp |
| Pixel 6/7/8 | `1080x2400` | `420` | ~411dp |
| 三星 S22/S23/S24 | `1080x2340` | `425` | ~407dp |
| 小米 13 / 一加 11 | `1080x2400` | `440` | ~393dp |
| OPPO/vivo 常见 1080p | `1080x2400` | `480` | 360dp |
| 华为 Mate 50 | `1260x2700` | `450` | 448dp |
| 2K 屏（小米/vivo 旗舰） | `1440x3200` | `560` | ~411dp |
| 三星 S23/S24 Ultra（QHD+） | `1440x3088` | `505` | ~456dp |
| Pixel 7 Pro/8 Pro | `1440x3120` | `560` | ~411dp |

## 平板 / 折叠屏 / POS（横屏可直接使用）

| 场景 | size | density | 逻辑宽度 |
|---|---|---|---|
| 入门安卓平板 / POS | `800x1280` | `213`（tvdpi） | ~601dp |
| 主流 POS 横屏 | `1280x800` | `213` | ~961dp |
| 10" 平板横屏 | `1920x1200` | `320` | 960dp |
| 10" 平板竖屏 | `1200x1920` | `320` | 600dp |
| 2K 平板横屏 | `2560x1600` | `320` | 1280dp |
| 折叠屏展开（横） | `2208x1768` | `420` | ~841dp |

## adb 切换命令

```powershell
# 老旧 720p 机
adb shell wm size 720x1280; adb shell wm density 320

# 经典 1080p
adb shell wm size 1080x1920; adb shell wm density 480

# Pixel 7/8
adb shell wm size 1080x2400; adb shell wm density 420

# 三星 S23
adb shell wm size 1080x2340; adb shell wm density 425

# 小米 13
adb shell wm size 1080x2400; adb shell wm density 440

# OPPO/vivo
adb shell wm size 1080x2400; adb shell wm density 480

# 华为 Mate 50
adb shell wm size 1260x2700; adb shell wm density 450

# 2K 旗舰
adb shell wm size 1440x3200; adb shell wm density 560

# POS 横屏
adb shell wm size 1280x800; adb shell wm density 213

# 平板横屏
adb shell wm size 1920x1200; adb shell wm density 320
```

## 恢复默认值

```powershell
adb shell wm size reset
adb shell wm density reset
```

## 注意事项

1. 先执行 `adb devices` 确认模拟器在线；连接多个设备时用 `-s` 指定，例如 `adb -s emulator-5554 shell wm size 1280x800`。
2. Flutter 中可用 `MediaQuery.of(context).size` 查看逻辑尺寸、`.devicePixelRatio` 查看倍率来验证是否生效；修改后若界面未刷新，执行热重启（`R`）而非热重载（`r`）。
3. 同样 1080 物理宽度下，density 480 对应 360dp、density 420 对应约 411dp，后者布局空间更大，对排版的影响比物理分辨率更直接。
