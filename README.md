# 万魔渊

《万魔渊》是一款修仙题材的生存 Roguelike。走位躲怪，让功法自动攻击；靠近灵晶攒经验，在功法卡牌中选择强化。每层生存时间结束时，魔尊登场。

**V4.0**：六境界、五秘境、每分钟一波兽潮、四阶段魔尊、四门新功法及九条局内进化路线。选层界面的金色「可进化」标记表示已满足搭档条件；基础功法升到 3 级后，下次升级可出现进化金卡。V3.1 存档可直接继续，无需清档。见 [V4 逐项自检](docs/V4-验收.md)。

`v3` 新增**局内刷宝、局外修仙**的循环：从外渊起步，刷装备和灵石，回洞府穿戴装备、领悟功法和突破境界，再挑战中渊、内渊。

**V3.1 仅打磨视觉**：统一界面样式，重做装备格子、洞府页签和战斗 HUD，并调整镜头构图与表现动画。玩法、数值、存档格式和操作流程沿用 `v3.0`。

`v2.5` 分支把战场迁移到 3D，采用固定斜 45° 透视镜头，保留 V2 的 2D 界面、玩法和数值。同屏最多 100 只怪，超出时暂停刷新。地图上的柱子和石头会阻挡玩家和怪物，但不阻挡飞剑和法球。

`main` 当前为 **V2 M1–M5**：新增灵石、局内法宝商店、购买与合成，以及战斗音效和特效。M6 真机打磨尚未完成。V1 基线见 [V1.0.0](https://github.com/ql0xdev/wanmoyuan/tree/v1.0.0)。

技术栈为 **Godot 4.7.2、GDScript、Compatibility 渲染器**，优先支持 Android 竖屏，Windows 可用于开发调试。

## 运行与操作

用 Godot 打开 `project.godot`，按 **F5** 启动。选择「开始修行」或「继续修行」进入洞府，点击「进入秘境」选择层数并配置功法。最多携带四个功法，首个选中的攻击功法开局生效，其余通过局内升级习得。

| 操作 | PC | Android |
| --- | --- | --- |
| 移动 | WASD 或方向键 | 战斗画面左右两侧均可按住并拖动摇杆 |
| 选择功法 | 鼠标点击或数字键 1–3 | 点按卡牌 |
| 打开炼丹房 / 行囊 | 点击右上角按钮 | 点按右上角按钮 |
| 暂停 / 保存 / 退出 | 点击「菜单」或按 Esc | 点按右上角「菜单」 |
| 再来一局 / 返回洞府 | 点击结算按钮 | 点按结算按钮 |

功法自动释放。蓝色灵晶用于本局升级；金色灵石可在炼丹房当场服用丹药，剩余部分可带回洞府。装备掉在地上，名称按品质着色，绿、蓝、紫装带光柱，白装不发光。靠近才会拾取到行囊；行囊满时，实际拾取的新装备仍自动分解为灵石。增益丹药每种每局只能服用一次，回血丹可以重复购买。

胜败均可带回本局已拾取的收获。击败魔尊后进入 10 秒离场倒计时，期间可安全走动拾取装备和金色灵石。时间到自动结算，未拾取的掉落不带回。返回洞府后可穿戴或分解装备；若装备库已满，需先整理战利品。「再来一局」沿用层数和功法配置，不继承上一局的临时状态。存档位于 `user://save.cfg`；如结算提示保存失败，可原地重试。

洞府和战斗右上角的「菜单」都能手动保存或「保存并退出」。战斗菜单会暂停游戏；手动存档只保存洞府进度，选择「退出游戏」并确认会放弃本局的未结算收获，下次从洞府继续。

要带走战利品而不继续打，可在战斗菜单选择「退出战斗」→「撤离并结算」。这会立即保存本局剩余灵石和新获得的装备，不计秘境通关；地上未拾取的掉落不会带回。

### V3 桌面回归测试

在项目根目录通过 PowerShell 运行（`$godot` 指向 Godot 4.7.2 的控制台可执行文件）。用子 PowerShell 或专用测试终端运行，避免该终端的 `APPDATA` 影响其他程序。

```powershell
$env:APPDATA = Join-Path ([System.IO.Path]::GetTempPath()) ("wanmoyuan-v3-test-" + [guid]::NewGuid())
& $godot --headless --path . --script res://tests/v3.gd -- play
& $godot --headless --path . --script res://tests/v3.gd -- exit
& $godot --headless --path . --script res://tests/v3.gd -- reload
Set-Content (Join-Path $env:APPDATA 'Godot\app_userdata\WanMoYuan\save.cfg') "[save]`nversion=999"
& $godot --headless --path . --script res://tests/v3.gd -- invalid
```

固定 100 怪的内渊渲染压测用 `--script res://tests/v3.gd -- stress`（换一个空的隔离 `APPDATA`，不要加 `--headless`）。流程测试会模拟部分战斗和拾取，不代表数值手感或真机验收。

撤离结算、地面掉落、胜利后的 10 秒离场分别用 `--headless --script res://tests/v3.gd -- retreat|loot|evacuation` 测试，每次选择一种模式并使用空的隔离 `APPDATA`。

视觉对照可在 `v3.0` 和 V3.1 各运行一次 `--resolution 540x960 --script res://tests/v3_visual_capture.gd -- <截图输出目录>`。每次用新的隔离 `APPDATA`；基线副本需复制该截图脚本。脚本输出 14 个界面的截图和逻辑投影采样。

突破、滑入和 Boss 登场可用 `--resolution 540x960 --script res://tests/v3_polish_capture.gd -- <截图输出目录>` 验证。同样使用隔离 `APPDATA`，不要加 `--headless`；脚本会加速跑完整的 180 秒战斗计时，再用正常速度截图。

### V4 桌面回归测试

每次运行前重新设置隔离 `APPDATA`，`$godot` 指向控制台版 Godot 4.7.2：

```powershell
$env:APPDATA = Join-Path $env:LOCALAPPDATA ('Temp/opencode/wanmoyuan-v4-test-' + [guid]::NewGuid())
& $godot --headless --path . --script res://tests/v4.gd -- full
```

`full` 覆盖五层、六境界、掉落和九条进化；`legacy` 单独检查 V3 存档迁移。可改用 `--resolution 540x960`（不加 `--headless`），脚本参数换成 `capture <输出目录>`、`legacy <输出目录>` 或 `stress <输出目录>`，分别重拍逐项自检、旧档和 100 怪负载截图。测试夹具不会进入正式导出包。

## Android 部署

Android 导出预设支持 Godot USB 一键部署，包名为 `com.wanmoyuan.demonabyss`。使用 JDK 17、Android SDK 和与引擎版本匹配的导出模板，具体配置见 [Android USB 部署说明](docs/Android-USB部署.md)。源码仓库不包含 APK 或生成的 Android 构建目录。

真机建议从外渊完整刷一轮：检查触控、安全区、选牌与拾取；分别花 500／2000／8000／30000／100000 灵石突破，再先进四层、五层，重启后核对存档。另测五层 05:00 兽潮和天相第四阶段弹幕重叠时的帧时间，以及连续游玩 10 分钟后的发热及降频。

## 设计文档

- [V2.5 设计文档](docs/万魔渊-设计文档V2.5.md)：3D 迁移与性能验收标准。
- [V2 设计文档](docs/万魔渊-设计文档V2.md)：灵石经济、法宝商店及开发里程碑。
- [V1 设计文档](docs/万魔渊-设计文档V1.md)：初始设计；已验收的平衡和操作调整以 V1.0.0 实际行为为准。
