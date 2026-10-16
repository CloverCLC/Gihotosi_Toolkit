# 吉太工具箱

给吉他用的调音器和节拍器，Android 应用。名字来自《轻音少女》里平泽唯那把吉他的外号「吉太」。

当前版本 **1.0.0**。

## 下载安装

到 [Releases](https://github.com/CloverCLC/Gihotosi_Toolkit/releases) 下载最新 APK，例如：

[Gihotosi_Toolkit-1.0.0-arm64.apk](https://github.com/CloverCLC/Gihotosi_Toolkit/releases/download/v1.0.0/Gihotosi_Toolkit-1.0.0-arm64.apk)

安装前在系统里允许「安装未知应用」。包只支持 **arm64-v8a**（现在主流安卓机）。首次使用调音器需要麦克风权限。

## 功能

三个页面：调音器、节拍器、关于。调音器才会打开麦克风；离开这个页面，或切到后台，麦克风会关掉。节拍器在离开页面时也会停。

### 调音器

标准六弦，A4 = 440 Hz。

| 弦 | 音 | 大约频率 |
| --- | --- | --- |
| 6 | E2 | 82.4 Hz |
| 5 | A2 | 110.0 Hz |
| 4 | D3 | 146.8 Hz |
| 3 | G3 | 196.0 Hz |
| 2 | B3 | 246.9 Hz |
| 1 | E4 | 329.6 Hz |

- 顶部显示当前目标音高。未选弦时是「自动」，点某一弦后只显示这根弦的目标频率；再点一次回到自动。
- 点中间的表盘，在指针和轨迹之间切换。轨迹的横轴是目标音两侧各一个半音，纵轴是时间。
- 偏差在 ±5 音分以内视为准。

### 节拍器

- BPM 20–250。
- 拍号：2/4、3/4、4/4、5/4、6/4、7/4、3/8、6/8、9/8、12/8。
- 圆点实心是强拍，空心是弱拍。点一下可以改这一拍的强弱；换拍号后恢复该拍号的默认重音。

## 从源码运行

### 环境

- Flutter 3.47 或与 `pubspec.yaml` 中 SDK 约束兼容的版本（Dart 3.13+）
- Android SDK
- 一台 **arm64-v8a** 的 Android 手机。工程只打这个 ABI，模拟器若是 x86_64 会装不上

```bash
flutter pub get
flutter run
```

已连接设备时可以直接指定：

```bash
flutter run -d <设备号>
```

打 debug 包：

```bash
flutter build apk --debug
```

打正式包（需要本机已有 `android/key.properties` 和签名密钥）：

```bash
flutter build apk --release
```

产物在 `build/app/outputs/flutter-apk/`。

部分机型（例如小米）需要在开发者选项里允许 USB 安装，否则会报 `INSTALL_FAILED_USER_RESTRICTED`。

## 目录

```text
lib/
  features/tuner/       调音器
  features/metronome/   节拍器
  features/about/       关于
  core/music/           音高与标准调弦
assets/sounds/          强弱拍点击声
assets/icon/            应用图标源图
```

## 作者

[CloverCLC](https://github.com/CloverCLC)

## 许可

[MIT](LICENSE)
