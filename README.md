# 万魔渊

《万魔渊》是一款修仙题材的生存 Roguelike。走位躲怪，让功法自动攻击；靠近灵晶攒经验，在三张功法卡牌中选择强化。存活至第 180 秒，击败魔尊即可渡劫成功。

`v3` 新增**局内刷宝、局外修仙**的循环：从外渊起步，刷装备和灵石，回洞府穿戴装备、领悟功法和突破境界，再挑战中渊、内渊。

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

功法自动释放。蓝色灵晶用于本局升级；金色灵石可在炼丹房当场服用丹药，剩余部分可带回洞府。两种掉落都须靠近拾取。装备掉落直接进入行囊，可在战斗暂停时换装；行囊满了，新掉的装备会自动分解成灵石。增益丹药每种每局只能服用一次，回血丹可以重复购买。

胜败均可带回本局收获；魔尊的灵石仍需实际拾取。返回洞府后可穿戴或分解装备；若装备库已满，需先整理战利品。「再来一局」沿用层数和功法配置，不继承上一局的临时状态。存档位于 `user://save.cfg`；如结算提示保存失败，可原地重试。

洞府和战斗右上角的「菜单」都能手动保存或「保存并退出」。战斗菜单会暂停游戏；手动存档只保存洞府进度，战斗中确认退出会放弃本局的未结算收获，下次从洞府继续。

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

## Android 部署

Android 导出预设支持 Godot USB 一键部署，包名为 `com.wanmoyuan.demonabyss`。使用 JDK 17、Android SDK 和与引擎版本匹配的导出模板，具体配置见 [Android USB 部署说明](docs/Android-USB部署.md)。源码仓库不包含 APK 或生成的 Android 构建目录。

真机建议从外渊完整刷一轮开始：检查触控与安全区 → 带回灵石及装备 → 攒够 500 突破筑基 → 挑战中渊 → 攒够 2000 突破金丹 → 挑战内渊 → 杀后台重启核对存档。另测 100 怪帧率和连续游玩 10 分钟后的发热及降频。

## 设计文档

- [V2.5 设计文档](docs/万魔渊-设计文档V2.5.md)：3D 迁移与性能验收标准。
- [V2 设计文档](docs/万魔渊-设计文档V2.md)：灵石经济、法宝商店及开发里程碑。
- [V1 设计文档](docs/万魔渊-设计文档V1.md)：初始设计；已验收的平衡和操作调整以 V1.0.0 实际行为为准。
