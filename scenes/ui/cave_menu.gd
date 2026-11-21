extends Control

const BATTLE_SCENE := "res://scenes/main.tscn"
const Catalog = preload("res://scripts/cultivation_catalog.gd")
const StatsManager = preload("res://scripts/stats_manager.gd")
const GearMenu = preload("res://scenes/ui/equipment_menu.gd")
const GameMenu = preload("res://scenes/ui/game_menu.gd")

@onready var _title: Label = $SafeArea/Margin/Content/Header/Title
@onready var _tabs: TabContainer = $SafeArea/Margin/Content/Tabs
@onready var _realm: Label = $SafeArea/Margin/Content/Tabs/修行/Scroll/Details/Realm
@onready var _stats: Label = $SafeArea/Margin/Content/Tabs/修行/Scroll/Details/Stats
@onready var _progress: Label = $SafeArea/Margin/Content/Tabs/修行/Scroll/Details/Progress
@onready var _breakthrough: Button = $SafeArea/Margin/Content/Tabs/修行/Scroll/Details/Breakthrough
@onready var _skill_tree: VBoxContainer = $SafeArea/Margin/Content/Tabs/功法/Tree
@onready var _storage: GearMenu = $SafeArea/Margin/Content/Tabs/行囊
@onready var _stones: Label = $SafeArea/Margin/Content/Stones
@onready var _status: Label = $SafeArea/Margin/Content/Status
@onready var _enter: Button = $SafeArea/Margin/Content/Enter
@onready var _preparation: ScrollContainer = $SafeArea/Margin/Content/Preparation
@onready var _prep_options: VBoxContainer = $SafeArea/Margin/Content/Preparation/Options
@onready var _prep_info: Label = $SafeArea/Margin/Content/LoadoutInfo
@onready var _back: Button = $SafeArea/Margin/Content/Back
@onready var _flash: ColorRect = $BreakthroughFlash
@onready var _notice: Label = $BreakthroughNotice
@onready var _game_menu: GameMenu = $SafeArea/GameMenu

var _points: Label
var _skill_nodes := {}
var _passive_nodes := {}
var _abyss_buttons := {}
var _loadout_buttons := {}
var _skill_options: VBoxContainer
var _selected_abyss := Catalog.DEFAULT_ABYSS
var _loadout: Array = Catalog.DEFAULT_LOADOUT.duplicate()
var _flash_tween: Tween


func _ready() -> void:
	_storage.wear_requested.connect(_wear_equipment)
	_storage.salvage_requested.connect(_salvage_equipment)
	_game_menu.closed.connect(_resume_cave)
	_build_skill_tree()
	_build_preparation()
	_refresh()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_open_game_menu()


func _open_game_menu() -> void:
	get_tree().paused = true
	_game_menu.open(false)


func _resume_cave() -> void:
	get_tree().paused = false


func _refresh() -> void:
	var stats := StatsManager.new()
	var worn := SaveManager.equipped_items()
	stats.configure(SaveManager.realm(), SaveManager.passive_levels(), worn)
	_realm.text = "当前境界 · %s" % SaveManager.realm_name()
	_stats.text = "气血上限 %d　攻击倍率 ×%.2f\n移速 %d　拾取范围 %d\n冷却缩减 %d%%　受伤减免 %d%%\n灵石掉落倍率 ×%.2f　击杀回血 %d" % [
		stats.max_health(), stats.attack_multiplier(), roundi(stats.move_speed()), roundi(stats.magnet_radius),
		roundi((1.0 - stats.cooldown_multiplier) * 100.0), roundi((1.0 - stats.damage_taken_multiplier()) * 100.0),
		stats.stone_multiplier(), stats.kill_heal(),
	]
	var progress := PackedStringArray()
	for abyss: String in Catalog.ABYSSES:
		var descriptor := "未通关"
		if SaveManager.has_cleared(abyss):
			descriptor = "已通关"
		elif not SaveManager.is_unlocked(abyss):
			descriptor = "未解锁"
		progress.append("%s %s" % [Catalog.ABYSSES[abyss].name, descriptor])
	_progress.text = "　".join(progress)
	_stones.text = "洞府灵石  %d" % SaveManager.spirit_stones()

	var target: String = Catalog.REALMS[SaveManager.realm()].next
	_breakthrough.disabled = target.is_empty() or SaveManager.spirit_stones() < Catalog.REALMS[target].cost
	_breakthrough.text = "已达金丹" if target.is_empty() else "突破·%s（%d 灵石）" % [Catalog.REALMS[target].name, Catalog.REALMS[target].cost]
	_refresh_skill_tree()
	_storage.display(GearMenu.Mode.STORAGE, SaveManager.storage(), worn)


func _break_through() -> void:
	if SaveManager.breakthrough() != OK:
		_show_status("无法完成突破，请检查灵石或存档。")
		return
	_refresh()
	_show_status("")
	if _flash_tween != null:
		_flash_tween.kill()
	_flash.modulate.a = 1.0
	_notice.modulate.a = 1.0
	_notice.text = "突破·%s" % SaveManager.realm_name()
	_flash.show()
	_notice.show()
	_flash_tween = create_tween().set_parallel()
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, 0.55)
	_flash_tween.tween_property(_notice, "modulate:a", 0.0, 0.35).set_delay(0.9)
	_flash_tween.chain().tween_callback(_hide_flash)


func _hide_flash() -> void:
	_flash.hide()
	_notice.hide()


func _build_skill_tree() -> void:
	_points = _add_label(_skill_tree, "", 27)
	_points.modulate = Color("#ffda91")
	_add_label(_skill_tree, "├ 主动功法\n　初始：御剑术、雷诀、护体罡气、冰心咒、回春功", 23)
	for skill: String in Catalog.SKILLS:
		var node: Dictionary = Catalog.SKILL_DATA[skill]
		if node.cost == 0:
			continue
		_skill_nodes[skill] = _add_tree_row(node.name, node.detail, _learn.bind(skill))
	_add_label(_skill_tree, "└ 心法 · 永久生效", 23)
	for id: String in Catalog.PASSIVES:
		var node: Dictionary = Catalog.PASSIVES[id]
		_passive_nodes[id] = _add_tree_row(node.name, node.detail, _train.bind(id))


func _add_tree_row(title: String, detail: String, action: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_skill_tree.add_child(row)
	var label := _add_label(row, "│ %s\n   %s" % [title, detail], 22)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var button := _add_button(row, 48)
	button.custom_minimum_size.x = 168
	button.pressed.connect(action)
	return {"label": label, "button": button}


func _refresh_skill_tree() -> void:
	var points := SaveManager.skill_points()
	var learned := SaveManager.learned_skills()
	var passives := SaveManager.passive_levels()
	_points.text = "功法点  %d" % points
	for id: String in _skill_nodes:
		var button: Button = _skill_nodes[id].button
		var cost: int = Catalog.SKILL_DATA[id].cost
		button.text = "已领悟" if learned.has(id) else "领悟 · %d 点" % cost
		button.disabled = learned.has(id) or points < cost
	for id: String in _passive_nodes:
		var ui: Dictionary = _passive_nodes[id]
		var node: Dictionary = Catalog.PASSIVES[id]
		var level: int = passives.get(id, 0)
		ui.label.text = "│ %s  %d/%d\n   %s" % [node.name, level, node.max, node.detail]
		ui.button.disabled = points < 1 or level >= node.max
		ui.button.text = "已满级" if level >= node.max else "加点 · 1 点"


func _learn(id: String) -> void:
	_show_status("已领悟 %s" % Catalog.SKILL_DATA[id].name if SaveManager.learn_skill(id) == OK else "领悟失败，存档未变更。")
	_refresh()


func _train(id: String) -> void:
	_show_status("已提升 %s" % Catalog.PASSIVES[id].name if SaveManager.train_passive(id) == OK else "加点失败，存档未变更。")
	_refresh()


func _wear_equipment(id: int, equip: bool) -> void:
	if SaveManager.change_equipment(id, equip) != OK:
		_storage.show_status("无法更换装备，存档未变更。")
		return
	_refresh()
	_storage.show_status("已穿戴并保存。" if equip else "已卸下并保存。")


func _salvage_equipment(id: int) -> void:
	var previous := SaveManager.spirit_stones()
	if SaveManager.salvage_equipment(id) != OK:
		_storage.show_status("分解失败，存档未变更。")
		return
	_refresh()
	_storage.show_status("已分解 · +%d 灵石" % (SaveManager.spirit_stones() - previous))


func _build_preparation() -> void:
	_add_label(_prep_options, "选择秘境", 27)
	for abyss: String in Catalog.ABYSSES:
		var button := _add_button(_prep_options, 65)
		button.toggle_mode = true
		button.pressed.connect(_choose_abyss.bind(abyss))
		_abyss_buttons[abyss] = button
	_add_label(_prep_options, "携带功法 · 最多四个，至少一个攻击功法", 24)
	_skill_options = VBoxContainer.new()
	_skill_options.add_theme_constant_override("separation", 8)
	_prep_options.add_child(_skill_options)


func _show_preparation() -> void:
	_show_status("")
	_tabs.hide()
	_preparation.show()
	_prep_info.show()
	_back.show()
	_title.text = "秘境准备"
	_preparation.scroll_vertical = 0
	_rebuild_loadout()
	_refresh_preparation()


func _hide_preparation() -> void:
	_show_status("")
	_tabs.show()
	_preparation.hide()
	_prep_info.hide()
	_back.hide()
	_title.text = "洞府"
	_enter.text = "进入秘境"
	_enter.disabled = false


func _rebuild_loadout() -> void:
	for child: Node in _skill_options.get_children():
		_skill_options.remove_child(child)
		child.queue_free()
	_loadout_buttons.clear()
	for id: String in SaveManager.learned_skills():
		var node: Dictionary = Catalog.SKILL_DATA[id]
		var button := _add_button(_skill_options, 54)
		button.toggle_mode = true
		button.text = "%s　·　%s" % [node.name, "攻击" if node.attack else "辅助"]
		button.tooltip_text = node.detail
		button.pressed.connect(_toggle_skill.bind(id))
		_loadout_buttons[id] = button


func _choose_abyss(id: String) -> void:
	if SaveManager.is_unlocked(id):
		_selected_abyss = id
	_refresh_preparation()


func _toggle_skill(id: String) -> void:
	if _loadout.has(id):
		_loadout.erase(id)
	elif _loadout.size() < Catalog.MAX_LOADOUT and SaveManager.learned_skills().has(id):
		_loadout.append(id)
	_refresh_preparation()


func _refresh_preparation() -> void:
	for id: String in _abyss_buttons:
		var abyss: Dictionary = Catalog.ABYSSES[id]
		var button: Button = _abyss_buttons[id]
		button.disabled = not SaveManager.is_unlocked(id)
		button.set_pressed_no_signal(id == _selected_abyss)
		var context := "需突破%s" % Catalog.REALMS[abyss.realm].name if button.disabled else ("已通关" if SaveManager.has_cleared(id) else "可进入")
		button.text = "%s　·　%s" % [abyss.name, context]
	for id: String in _loadout_buttons:
		var button: Button = _loadout_buttons[id]
		var selected := _loadout.has(id)
		button.set_pressed_no_signal(selected)
		button.disabled = not selected and _loadout.size() >= Catalog.MAX_LOADOUT
	var first := Catalog.first_attack(_loadout)
	var label := "请选择一个攻击功法" if first.is_empty() else "开局 %s；其余通过升级习得" % Catalog.SKILL_DATA[first].name
	_prep_info.text = "已选 %d/%d · %s" % [_loadout.size(), Catalog.MAX_LOADOUT, label]
	_enter.disabled = not SaveManager.valid_loadout(_loadout)
	_enter.text = "开战 · %s" % Catalog.ABYSSES[_selected_abyss].name


func _enter_battle() -> void:
	if not _preparation.visible:
		_show_preparation()
		return
	var scene := load(BATTLE_SCENE) as PackedScene
	if scene == null:
		_show_status("无法进入秘境，请重试。")
		return
	var battle := scene.instantiate()
	if not battle.configure_run(_selected_abyss, _loadout) or get_tree().change_scene_to_node(battle) != OK:
		battle.free()
		_show_status("无法进入秘境，请检查境界与功法。")


func _show_status(text: String) -> void:
	_status.text = text
	_status.visible = not text.is_empty()


func _add_label(parent: Control, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	parent.add_child(label)
	return label


func _add_button(parent: Control, height: float) -> Button:
	var button := Button.new()
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", 24)
	parent.add_child(button)
	return button
