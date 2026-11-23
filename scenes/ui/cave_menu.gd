extends Control

const BATTLE_SCENE := "res://scenes/main.tscn"
const Catalog = preload("res://scripts/cultivation_catalog.gd")
const StatsManager = preload("res://scripts/stats_manager.gd")
const GearMenu = preload("res://scenes/ui/equipment_menu.gd")
const Forge = preload("res://scripts/forge_catalog.gd")
const ForgeMenu = preload("res://scenes/ui/forge_menu.gd")
const SacrificePicker = preload("res://scenes/ui/forge_sacrifice.gd")
const ForgeFlash = preload("res://scenes/ui/forge_flash.gd")
const GameMenu = preload("res://scenes/ui/game_menu.gd")
const Look = preload("res://scenes/ui/ui_look.gd")
const Backdrop = preload("res://scenes/ui/ui_backdrop.gd")
const STAT_LABELS := ["气血上限", "攻击倍率", "移速", "拾取范围", "冷却缩减", "受伤减免", "灵石掉落倍率", "击杀回血"]

@onready var _title: Label = $SafeArea/Margin/Content/Header/Title
@onready var _tabs: TabContainer = $SafeArea/Margin/Content/Tabs
@onready var _realm: Label = $SafeArea/Margin/Content/Tabs/修行/Scroll/Details/Realm
@onready var _stats: GridContainer = $SafeArea/Margin/Content/Tabs/修行/Scroll/Details/Stats
@onready var _progress: Label = $SafeArea/Margin/Content/Tabs/修行/Scroll/Details/Progress
@onready var _breakthrough: Button = $SafeArea/Margin/Content/Tabs/修行/Scroll/Details/Breakthrough
@onready var _breakthrough_bar: ProgressBar = $SafeArea/Margin/Content/Tabs/修行/Scroll/Details/BreakthroughBar
@onready var _breakthrough_progress: Label = $SafeArea/Margin/Content/Tabs/修行/Scroll/Details/BreakthroughProgress
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
@onready var _cave_layout: Control = $SafeArea/Margin
@onready var _backdrop: Backdrop = $Background

var _points: Label
var _skill_nodes := {}
var _passive_nodes := {}
var _stat_values: Array[Label] = []
var _learned_card := Look.box(Look.BACKGROUND, Look.GOLD)
var _locked_card := Look.box(Look.BACKGROUND, Look.BORDER)
var _abyss_buttons := {}
var _selected_abyss := Catalog.DEFAULT_ABYSS
var _flash_tween: Tween
var _forge_menu: ForgeMenu
var _picker: SacrificePicker
var _forge_flash: ForgeFlash
var _star_grid: GearMenu
var _star_id := 0


func _ready() -> void:
	_connect_gear_grid(_storage)
	_forge_menu = ForgeMenu.new()
	_forge_menu.name = "熔炉"
	_tabs.add_child(_forge_menu)
	_connect_gear_grid(_forge_menu.gear)
	_forge_menu.crafted.connect(_refresh)
	_picker = SacrificePicker.new()
	$SafeArea.add_child(_picker)
	_picker.confirmed.connect(_confirm_star)
	_forge_flash = ForgeFlash.new()
	$SafeArea.add_child(_forge_flash)
	_forge_menu.masterwork.connect(_forge_flash.flash.bind("神匠一击"))
	_game_menu.closed.connect(_resume_cave)
	_build_stat_tiles()
	_build_skill_tree()
	_build_preparation()
	Look.skin_buttons(self)
	_refresh()


func _connect_gear_grid(grid: GearMenu) -> void:
	grid.attach_tooltip($SafeArea)
	grid.wear_requested.connect(_wear_equipment.bind(grid))
	grid.salvage_requested.connect(_salvage_equipment.bind(grid))
	grid.star_requested.connect(_open_star.bind(grid))


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
	_realm.text = SaveManager.realm_name()
	var values := [
		str(stats.max_health()), "×%.2f" % stats.attack_multiplier(),
		str(roundi(stats.move_speed())), str(roundi(stats.magnet_radius)),
		"%d%%" % roundi((1.0 - stats.cooldown_multiplier) * 100.0),
		"%d%%" % roundi((1.0 - stats.damage_taken_multiplier()) * 100.0),
		"×%.2f" % stats.stone_multiplier(), str(stats.kill_heal()),
	]
	for i in range(values.size()):
		_stat_values[i].text = values[i]
	var progress := PackedStringArray()
	for abyss: String in Catalog.ABYSSES:
		var descriptor := "未通关"
		if SaveManager.has_cleared(abyss):
			descriptor = "已通关"
		elif not SaveManager.is_unlocked(abyss):
			descriptor = "未解锁"
		progress.append("%s %s" % [Catalog.ABYSSES[abyss].name, descriptor])
	_progress.text = "　".join(progress)
	_stones.text = "洞府灵石 %d　·　玄铁 %d" % [SaveManager.spirit_stones(), SaveManager.iron()]

	var target: String = Catalog.REALMS[SaveManager.realm()].next
	_breakthrough.disabled = target.is_empty() or SaveManager.spirit_stones() < Catalog.REALMS[target].cost
	_breakthrough.text = "已达%s" % SaveManager.realm_name() if target.is_empty() else "突破·%s（%d 灵石）" % [Catalog.REALMS[target].name, Catalog.REALMS[target].cost]
	_breakthrough_bar.visible = not target.is_empty()
	_breakthrough_progress.visible = not target.is_empty()
	if not target.is_empty():
		var cost: int = Catalog.REALMS[target].cost
		_breakthrough_bar.max_value = float(cost)
		_breakthrough_bar.value = float(SaveManager.spirit_stones())
		_breakthrough_progress.text = "%d / %d 灵石" % [SaveManager.spirit_stones(), cost]
	_refresh_skill_tree()
	_storage.display(GearMenu.Mode.STORAGE, SaveManager.storage(), worn, 0, SaveManager.iron())
	_forge_menu.refresh()


func _build_stat_tiles() -> void:
	_style_progress(_breakthrough_bar, Look.GOLD)
	for title: String in STAT_LABELS:
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", _locked_card)
		_stats.add_child(panel)
		var row := HBoxContainer.new()
		panel.add_child(row)
		var caption := _add_label(row, title, 20)
		caption.modulate = Look.MUTED
		caption.autowrap_mode = TextServer.AUTOWRAP_OFF
		caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value := _add_label(row, "", 24)
		value.modulate = Look.CYAN
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_stat_values.append(value)


func _break_through() -> void:
	if SaveManager.breakthrough() != OK:
		_show_status("无法完成突破，请检查灵石或存档。")
		return
	_refresh()
	_show_status("")
	if _flash_tween != null:
		_flash_tween.kill()
	_flash.modulate.a = 0.88
	_notice.modulate.a = 1.0
	_notice.text = "突破·%s" % SaveManager.realm_name()
	_flash.show()
	_notice.show()
	_notice.pivot_offset = _notice.size * 0.5
	_notice.scale = Vector2.ONE * 0.85
	_flash_tween = create_tween().set_parallel()
	_flash_tween.tween_property(_flash, "modulate:a", 0.0, 0.52).set_delay(0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(_notice, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_method(_shake_breakthrough, 0.0, 1.0, 0.30)
	_flash_tween.tween_property(_notice, "modulate:a", 0.0, 0.35).set_delay(1.50)
	_flash_tween.chain().tween_callback(_hide_flash)


func _shake_breakthrough(progress: float) -> void:
	var offset := Look.shake_offset(progress, 18.0)
	_cave_layout.position = offset
	_backdrop.ornament_offset = _cave_layout.position


func _hide_flash() -> void:
	_flash.hide()
	_notice.hide()


func _build_skill_tree() -> void:
	_points = _add_label(_skill_tree, "", 24)
	_points.modulate = Look.CYAN
	_add_label(_skill_tree, "主动功法", 32).modulate = Look.GOLD
	var icon_active := Look.swatch(Color("#356a65"), Vector2i(32, 32))
	var icon_passive := Look.swatch(Color("#625079"), Vector2i(32, 32))
	var starters := GridContainer.new()
	starters.columns = 2
	starters.add_theme_constant_override("h_separation", 8)
	starters.add_theme_constant_override("v_separation", 8)
	_skill_tree.add_child(starters)
	for skill: String in Catalog.SKILLS:
		var node: Dictionary = Catalog.SKILL_DATA[skill]
		if node.cost == 0:
			_add_tree_card(starters, node.name, "初始 · 已领悟", icon_active, _learned_card)
			continue
	for skill: String in Catalog.SKILLS:
		var node: Dictionary = Catalog.SKILL_DATA[skill]
		if node.cost > 0:
			var card := _add_tree_card(_skill_tree, node.name, "%s · %d 点" % [node.detail, node.cost], icon_active, _locked_card)
			_add_tree_action(card, _learn.bind(skill))
			_skill_nodes[skill] = card
	_add_label(_skill_tree, "心法 · 永久生效", 32).modulate = Look.GOLD
	for id: String in Catalog.PASSIVES:
		var node: Dictionary = Catalog.PASSIVES[id]
		var card := _add_tree_card(_skill_tree, node.name, node.detail, icon_passive, _locked_card)
		var meter := ProgressBar.new()
		meter.max_value = node.max
		meter.show_percentage = false
		meter.custom_minimum_size.y = 12
		_style_progress(meter, Look.CYAN)
		card.details.add_child(meter)
		var rank := _add_label(card.details, "", 20)
		rank.modulate = Look.CYAN
		card["rank"] = rank
		card["meter"] = meter
		_add_tree_action(card, _train.bind(id))
		_passive_nodes[id] = card


func _add_tree_card(parent: Control, title: String, detail: String, icon: Texture2D, style: StyleBoxFlat) -> Dictionary:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	var glyph := TextureRect.new()
	glyph.texture = icon
	glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(glyph)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(details)
	_add_label(details, title, 24)
	_add_label(details, detail, 20).modulate = Look.MUTED
	return {"panel": panel, "row": row, "details": details}


func _add_tree_action(card: Dictionary, action: Callable) -> void:
	var button := _add_button(card.row, 52)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size.x = 148
	button.pressed.connect(action)
	card["button"] = button


func _style_progress(bar: ProgressBar, ink: Color) -> void:
	bar.add_theme_stylebox_override("background", Look.box(Look.DISABLED, Color.TRANSPARENT, 0, 6, 0))
	bar.add_theme_stylebox_override("fill", Look.box(ink, Color.TRANSPARENT, 0, 6, 0))


func _refresh_skill_tree() -> void:
	var points := SaveManager.skill_points()
	var learned := SaveManager.learned_skills()
	var passives := SaveManager.passive_levels()
	_points.text = "功法点  %d" % points
	for id: String in _skill_nodes:
		var ui: Dictionary = _skill_nodes[id]
		var button: Button = ui.button
		var cost: int = Catalog.SKILL_DATA[id].cost
		button.text = "已领悟" if learned.has(id) else "领悟 · %d 点" % cost
		button.disabled = learned.has(id) or points < cost
		ui.panel.add_theme_stylebox_override("panel", _learned_card if learned.has(id) else _locked_card)
	for id: String in _passive_nodes:
		var ui: Dictionary = _passive_nodes[id]
		var node: Dictionary = Catalog.PASSIVES[id]
		var level: int = passives.get(id, 0)
		ui.meter.value = level
		ui.rank.text = "%d/%d" % [level, node.max]
		ui.button.disabled = points < 1 or level >= node.max
		ui.button.text = "已满级" if level >= node.max else "加点 · 1 点"


func _learn(id: String) -> void:
	_show_status("已领悟 %s" % Catalog.SKILL_DATA[id].name if SaveManager.learn_skill(id) == OK else "领悟失败，存档未变更。")
	_refresh()


func _train(id: String) -> void:
	_show_status("已提升 %s" % Catalog.PASSIVES[id].name if SaveManager.train_passive(id) == OK else "加点失败，存档未变更。")
	_refresh()


func _wear_equipment(id: int, equip: bool, grid: GearMenu) -> void:
	if SaveManager.change_equipment(id, equip) != OK:
		grid._popup.show_status("无法更换装备，存档未变更。")
		return
	_refresh()
	grid.show_status("已穿戴并保存。" if equip else "已卸下并保存。")


func _salvage_equipment(id: int, grid: GearMenu) -> void:
	var item: Dictionary = grid._items.get(id, {})
	if item.is_empty():
		return
	if SaveManager.salvage_equipment(id) != OK:
		grid._popup.show_status("分解失败，存档未变更。")
		return
	_refresh()
	grid.show_status("获得 " + Forge.salvage_text(item.quality))


func _open_star(id: int, grid: GearMenu) -> void:
	var item: Dictionary = grid._items.get(id, {})
	if item.is_empty():
		return
	var candidates := grid.star_candidates(item)
	var cost := Forge.star_cost(item)
	if not Forge.can_star(cost, SaveManager.iron(), candidates.size()):
		return
	_star_grid = grid
	_star_id = id
	_picker.open(item, candidates, cost)


func _confirm_star(ids: Array) -> void:
	if SaveManager.star_equipment(_star_id, ids) != OK:
		_star_grid._popup.show_status("升星失败，材料未扣除。")
		return
	_refresh()
	_forge_flash.flash("升星成功")


func _build_preparation() -> void:
	_add_label(_prep_options, "选择秘境", 27)
	for abyss: String in Catalog.ABYSSES:
		var button := _add_button(_prep_options, 65)
		button.toggle_mode = true
		button.pressed.connect(_choose_abyss.bind(abyss))
		_abyss_buttons[abyss] = button


func _show_preparation() -> void:
	_show_status("")
	_tabs.hide()
	_preparation.show()
	_prep_info.show()
	_back.show()
	_title.text = "秘境准备"
	_preparation.scroll_vertical = 0
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


func _choose_abyss(id: String) -> void:
	if SaveManager.is_unlocked(id):
		_selected_abyss = id
	_refresh_preparation()


func _refresh_preparation() -> void:
	for id: String in _abyss_buttons:
		var abyss: Dictionary = Catalog.ABYSSES[id]
		var button: Button = _abyss_buttons[id]
		button.disabled = not SaveManager.is_unlocked(id)
		button.set_pressed_no_signal(id == _selected_abyss)
		var context := "需突破%s" % Catalog.REALMS[abyss.realm].name if button.disabled else ("已通关" if SaveManager.has_cleared(id) else "可进入")
		button.text = "%s　·　%d 秒　·　%s" % [abyss.name, abyss.duration, context]
	_prep_info.text = "开局 御剑术 Lv1 · 其余已领悟功法可在局内抽取"
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
	if not battle.configure_run(_selected_abyss) or get_tree().change_scene_to_node(battle) != OK:
		battle.free()
		_show_status("无法进入秘境，请检查境界。")


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
	Look.skin_button(button)
	return button
