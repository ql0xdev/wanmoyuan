# 万魔渊

《万魔渊》是一款修仙题材的生存 Roguelike。走位躲怪，让功法自动攻击；击杀敌人积累修为，三选一习得或强化功法。

**V5.5**：局内改为原生 2D 正俯视角，角色、怪物、地面和技能全部程序化绘制。沿用 V5.0.2 玩法及 V6 存档。见 [V5.5 验收报告](docs/V5.5-验收.md)。

**V5.0**：镜头拉远 1.4 倍，兽潮增量，池化怪物上限提至 150。开局固定御剑术 Lv1，局内最多八格、功法最高 Lv5；300 秒一局，240 秒魔尊登场。见 [V5.0 逐项自检](docs/V5.0-验收.md)。

**V5.0.1**：恢复拾取修为灵石升级，调矮角色模型。见 [返修验证](docs/V5.0.1-返修.md)。

**V5.0.2**：三选一优先出功法，恢复击败魔尊后的 10 秒安全拾取，新增回春露与聚灵符。见 [调整与验证](docs/V5.0.2-调整.md)。

**V4.1**：装备浮窗可并列比较；洞府熔炉可熔炼、打造和升星。打造是补缺渠道，怪物直接掉落装备的规则不变。升级固定三选一，新增八种可叠加的属性卡与随机珍稀金卡。见 [V4.1 逐项自检](docs/V4.1-验收.md)。

**V4**：六境界、五秘境、每分钟一波兽潮、四阶段魔尊、四门新功法及九条局内进化路线。开局配装会写明哪门功法可以进化、所需搭档或心法，以及进化后的名称。进战斗把基础功法升到 3 级，之后升级时选择进化金卡。V3.1 存档可直接继续，无需清档。见 [V4 逐项自检](docs/V4-验收.md)。

`v3` 新增**局内刷宝、局外修仙**的循环：从外渊起步，刷装备和灵石，回洞府穿戴装备、领悟功法和突破境界，再挑战中渊、内渊。

**V3.1 仅打磨视觉**：统一界面样式，重做装备格子、洞府页签和战斗 HUD，并调整镜头构图与表现动画。玩法、数值、存档格式和操作流程沿用 `v3.0`。

`v2.5` 分支把战场迁移到 3D，采用固定斜 45° 透视镜头，保留 V2 的 2D 界面、玩法和数值。同屏最多 100 只怪，超出时暂停刷新。地图上的柱子和石头会阻挡玩家和怪物，但不阻挡飞剑和法球。

`main` 当前为 **V2 M1–M5**：新增灵石、局内法宝商店、购买与合成，以及战斗音效和特效。M6 真机打磨尚未完成。V1 基线见 [V1.0.0](https://github.com/ql0xdev/wanmoyuan/tree/v1.0.0)。

技术栈为 **Godot 4.7.2、GDScript、Compatibility 渲染器**，优先支持 Android 竖屏，Windows 可用于开发调试。

## 运行与操作

用 Godot 打开 `project.godot`，按 **F5** 启动。选择「开始修行」或「继续修行」进入洞府，点击「进入秘境」选择层数。开局固定御剑术 Lv1；洞府已领悟的其他功法会出现在局内升级卡池。暂停菜单可以查看功法栏和进化条件。

| 操作 | PC | Android |
| --- | --- | --- |
| 移动 | WASD 或方向键 | 战斗画面左右两侧均可按住并拖动摇杆 |
| 选择功法 | 鼠标点击或数字键 1–3 | 点按卡牌 |
| 打开炼丹房 / 行囊 | 点击右上角按钮 | 点按右上角按钮 |
| 暂停 / 保存 / 退出 | 点击「菜单」或按 Esc | 点按右上角「菜单」 |
| 再来一局 / 返回洞府 | 点击结算按钮 | 点按结算按钮 |

功法自动释放。怪物掉落蓝色修为灵石，靠近吸取后才累积本局升级进度；地上的金色灵石仍可在炼丹房购买丹药，剩余部分可带回洞府。装备掉落的颜色和光柱不变。靠近才会拾取到行囊；行囊满时，实际拾取的新装备会自动分解为灵石和玄铁。增益丹药每种每局只能服用一次，回血丹可以重复购买。

击败魔尊后有 10 秒安全拾取时间，结束时自动通关结算。未捡到的掉落不会带回。存活至 300 秒也可结算，但不计魔尊通关。返回洞府后可穿戴或分解装备；若装备库已满，需先整理战利品。「再来一局」沿用层数，不继承上一局的临时状态。存档位于 `user://save.cfg`；如结算提示保存失败，可原地重试。

非 Boss 敌人还可能掉落绿色十字「回春露」和紫色圆环「聚灵符」。靠近拾取立即生效：回春露恢复最大气血的 30%；聚灵符收取全图此刻已掉落的金色灵石和蓝色修为灵晶，不收装备。

点击装备或拾取提示可查看属性，点窗外关闭。分解获得灵石和玄铁；带回的玄铁存入洞府。本局新装也可在行囊里熔炼、升星，花费本局玄铁和未穿戴的本局祭品；从洞府带入的装备请回洞府处理。打造在洞府选择部位和等级，成品入库。升星只提升基础属性，不会改动随机词条。

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

固定 150 怪的内渊渲染压测用 `--script res://tests/v3.gd -- stress`（换一个空的隔离 `APPDATA`，不要加 `--headless`）。流程测试会模拟部分战斗和拾取，不代表数值手感或真机验收。

撤离结算、地面掉落、魔尊胜利结算分别用 `--headless --script res://tests/v3.gd -- retreat|loot|evacuation` 测试，每次选择一种模式并使用空的隔离 `APPDATA`。

V3.1 的历史视觉对照请在对应版本运行 `tests/v3_visual_capture.gd`、`tests/v3_polish_capture.gd`。

### V4 桌面回归测试

每次运行前重新设置隔离 `APPDATA`，`$godot` 指向控制台版 Godot 4.7.2：

```powershell
$env:APPDATA = Join-Path $env:LOCALAPPDATA ('Temp/opencode/wanmoyuan-v4-test-' + [guid]::NewGuid())
& $godot --headless --path . --script res://tests/v4.gd -- full
```

`full` 覆盖五层、六境界、掉落和九条进化；`legacy` 单独检查 V3 存档迁移。可改用 `--resolution 540x960`（不加 `--headless`），脚本参数换成 `capture <输出目录>`、`legacy <输出目录>` 或 `stress <输出目录>`，分别重拍逐项自检、旧档和 100 怪负载截图。测试夹具不会进入正式导出包。

### V4.1 桌面回归测试

```powershell
$env:APPDATA = Join-Path $env:LOCALAPPDATA ('Temp/opencode/wanmoyuan-v41-test-' + [guid]::NewGuid())
& $godot --headless --path . --script res://tests/v41.gd -- full
```

每次用新的隔离 `APPDATA`。`full` 覆盖装备界面、熔炉与卡池；`legacy` 检查 V4 存档迁移。可用 `--resolution 540x960 --max-fps 60` 代替 `--headless`，再用 `capture <目录>`、`legacy <目录>` 或 `stress <目录>` 重拍自检。`tests/v41_drop_probe.gd` 可分别在 `v4.0` 与 V4.1 上运行，对照怪物装备掉落指纹。

### V5.0 桌面回归测试

```powershell
$env:APPDATA = Join-Path $env:LOCALAPPDATA ('Temp/opencode/wanmoyuan-v5-test-' + [guid]::NewGuid())
& $godot --headless --path . --script res://tests/v5.gd -- full
```

复拍用 `--resolution 540x960` 代替 `--headless`，脚本参数用 `capture <目录>`、`stress <目录>`，或 `legacy <目录> [V4.1 存档路径]`。原版透视对照脚本保留在 `v5.0` 标签。

### V5.5 表现层回归测试

```powershell
$env:APPDATA = Join-Path $env:LOCALAPPDATA ('Temp/opencode/wanmoyuan-v55-test-' + [guid]::NewGuid())
& $godot --path . --resolution 540x960 --script res://tests/v55.gd -- <截图目录> <V5旧档路径>
```

可用 `--headless` 且省略参数，只跑场景、碰撞与动画状态断言。150 怪压测用新的 `wanmoyuan-v5-test-*` 隔离目录，运行 `--resolution 540x960 --disable-vsync --max-fps 120 --script res://tests/v5.gd -- stress <截图目录>`。

## Android 部署

Android 安装包可从 [GitHub Releases](https://github.com/ql0xdev/wanmoyuan/releases) 下载。导出预设支持 Godot USB 一键部署，包名为 `com.wanmoyuan.demonabyss`。使用 JDK 17、Android SDK 和与引擎版本匹配的导出模板，具体配置见 [Android USB 部署说明](docs/Android-USB部署.md)。源码仓库不包含 APK 或生成的 Android 构建目录。

真机建议从外渊完整刷一轮：检查触控、安全区、选牌、进化与拾取，重启后核对存档。另测五层 04:00 兽潮、天相第四阶段与八门功法同屏时的帧时间，以及连续游玩后的发热及降频。

## 设计文档

- [V2.5 设计文档](docs/万魔渊-设计文档V2.5.md)：3D 迁移与性能验收标准。
- [V2 设计文档](docs/万魔渊-设计文档V2.md)：灵石经济、法宝商店及开发里程碑。
- [V1 设计文档](docs/万魔渊-设计文档V1.md)：初始设计；已验收的平衡和操作调整以 V1.0.0 实际行为为准。
