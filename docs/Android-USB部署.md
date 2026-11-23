# Android USB 调试部署

项目使用 Godot 4.7.2。`export_presets.cfg` 里的 `Android` 预设已标为 **Runnable**，导出为签名调试 APK，支持 ARM64 和 ARMv7。包名为 `com.wanmoyuan.demonabyss`，应用名为「万魔渊」。

## 首次连接

1. 若项目已打开，重新打开以加载新预设。在 Godot 打开 **编辑器 → 编辑器设置 → Export（导出）→ Android**。本机 `Java SDK Path` 填 `E:\Tools\jdk-17`，`Android SDK Path` 确认是 `C:\Users\Administrator\AppData\Local\Android\Sdk`。终端里的 `java` 即使仍指向 Java 9，也无需卸载它；Godot 使用这里填写的 JDK 17。
2. 手机开启开发者选项与 USB 调试，解锁后用支持数据传输的 USB 线连接电脑，在手机上确认「允许 USB 调试」。运行 `adb devices -l`，看到设备状态为 `device` 后再部署。若列表为空，先换线或 USB 口，再检查 Windows 的手机 ADB 驱动。
3. 在 Godot 右上角点击 Android 设备按钮，选中手机，即可导出、安装并启动调试版。部署后检查顶部 UI 是否避开挖孔、屏幕左右两侧都能唤出摇杆，以及升级卡牌点按和结算重开。

V4.0.1 本地调试 APK：`android/wanmoyuan-v4.0.1-debug.apk`（versionCode 11）。如需手动安装，可在项目根目录运行 `adb install -r .\android\wanmoyuan-v4.0.1-debug.apk`。只有签名一致才能覆盖安装；不要为解决签名冲突直接卸载已有版本，以免清除本地存档。

V4.1 本地调试 APK：`android/wanmoyuan-v4.1-debug.apk`（versionCode 12，Android 7.0+）。可用 `adb install -r .\android\wanmoyuan-v4.1-debug.apk` 覆盖安装同签名版本。旧档会在首次正常保存时迁移到 `save_version=5`；如需以后回退旧版本，先另行备份旧档。

V5.0 本地调试 APK：`android/wanmoyuan-v5.0-debug.apk`（versionCode 13，Android 7.0+）。可用 `adb install -r .\android\wanmoyuan-v5.0-debug.apk` 覆盖安装同签名版本。V4.1 存档首次成功保存迁移为 `save_version=6`；回退前请先备份旧档，不要直接卸载现有版本。

V5.0.1 返修 APK：`android/wanmoyuan-v5.0.1-debug.apk`（versionCode 14）。可用 `adb install -r .\android\wanmoyuan-v5.0.1-debug.apk` 覆盖同签名 V5.0，存档格式不变。

## 如果需要 Gradle 构建

USB 预设默认关闭 **Use Gradle Build**，直接使用 Godot 预编译模板。Gradle Build Template 已安装在 `android/build`；`android/` 是生成目录，新副本可通过 **项目 → 安装 Android 构建模板** 重新生成。

启用 Gradle 前，用 Android Studio 的 SDK Manager 或 `sdkmanager` 补齐本机 4.7.2 模板使用的 **SDK Platform 36**（`platforms;android-36`）、**Build-Tools 36.1.0**（`build-tools;36.1.0`）和 **NDK 29.0.14206865**（`ndk;29.0.14206865`），并建议更新 **Android SDK Command-line Tools (latest)**。使用原生组件时再按其要求安装 CMake。
