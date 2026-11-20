# 万魔渊

《万魔渊》是一款修仙题材的 2D 俯视角生存 Roguelike。走位躲怪，让功法自动攻击；靠近灵晶攒经验，在三张功法卡牌中选择强化。存活至第 180 秒，击败魔尊即可渡劫成功。

当前里程碑：[V1.0.0](https://github.com/ql0xdev/wanmoyuan/tree/v1.0.0)。技术栈为 **Godot 4.7.2、GDScript、Compatibility 渲染器**，优先支持 Android 竖屏，Windows 可用于开发调试。

## 运行与操作

用 Godot 打开 `project.godot`，按 **F5** 启动，选择「开始修行」。

| 操作 | PC | Android |
| --- | --- | --- |
| 移动 | WASD 或方向键 | 战斗画面左右两侧均可按住并拖动摇杆 |
| 选择功法 | 鼠标点击或数字键 1–3 | 点按卡牌 |
| 再来一局 | 点击结算按钮 | 点按结算按钮 |

功法自动释放。灵晶在原地等待，进入吸取范围后才会飞向玩家。

## Android 部署

Android 导出预设支持 Godot USB 一键部署，包名为 `com.wanmoyuan.demonabyss`。使用 JDK 17、Android SDK 和与引擎版本匹配的导出模板，具体配置见 [Android USB 部署说明](docs/Android-USB部署.md)。源码仓库不包含 APK 或生成的 Android 构建目录。

## 设计文档

参见 [《万魔渊》设计文档 V1](docs/万魔渊-设计文档V1.md)。文档记录初始设计；已验收的平衡和操作调整以 V1.0.0 实际行为为准。
