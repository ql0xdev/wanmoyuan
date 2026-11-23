extends RefCounted

const BACKGROUND := Color("#0d1117")
const PANEL := Color("#161b22")
const BORDER := Color("#30363d")
const GOLD := Color("#f0c674")
const TEXT := Color("#e6edf3")
const MUTED := Color("#8b949e")
const CYAN := Color("#56d4dd")
const GREEN := Color("#1f6f5c")
const DISABLED := Color("#21262d")
const DISABLED_TEXT := Color("#484f58")
const BUTTON_SHADER := preload("res://scenes/ui/button_feedback.gdshader")

static func box(fill: Color, border: Color = Color.TRANSPARENT, width := 1, radius := 8, padding := 16) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style


static func swatch(color: Color, shape_size: Vector2i) -> ImageTexture:
	var image := Image.create_empty(shape_size.x, shape_size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


static func evolution_box(hover := false) -> StyleBoxFlat:
	var style := box(Color("#634923") if hover else Color("#3d2c18"), GOLD, 3, 8, 8)
	style.shadow_color = Color(0.98, 0.69, 0.29, 0.36)
	style.shadow_size = 7
	return style


static func skin_buttons(root: Node) -> void:
	if root is Button:
		skin_button(root)
	for child in root.get_children():
		skin_buttons(child)


static func skin_button(button: Button) -> void:
	if button.has_meta(&"visual_feedback"):
		return
	button.set_meta(&"visual_feedback", true)
	button.resized.connect(_fit_button.bind(button))
	button.button_down.connect(press_feedback.bind(button, true))
	button.button_up.connect(press_feedback.bind(button, false))


static func _fit_button(button: Button) -> void:
	var material := button.material as ShaderMaterial
	if material != null and material.shader == BUTTON_SHADER:
		material.set_shader_parameter(&"button_extent", button.size)


static func press_feedback(button: Button, down: bool) -> void:
	if button.has_meta(&"feedback_tween"):
		var previous: Tween = button.get_meta(&"feedback_tween")
		previous.kill()
	var material := button.material as ShaderMaterial
	if material == null or material.shader != BUTTON_SHADER:
		# 只给正在按压的按钮挂材质，避免 200 个格子一起占用着色器实例槽。
		button.set_meta(&"feedback_original_material", [button.material])
		material = ShaderMaterial.new()
		material.shader = BUTTON_SHADER
		material.set_shader_parameter(&"press_scale", 1.0)
		button.material = material
	_fit_button(button)
	var current: float = material.get_shader_parameter(&"press_scale")
	var tween := button.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	button.set_meta(&"feedback_tween", tween)
	tween.tween_method(
		func(value: float) -> void: material.set_shader_parameter(&"press_scale", value),
		current if down else minf(current, 0.96), 0.94 if down else 1.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not down:
		tween.tween_callback(func() -> void:
			button.material = button.get_meta(&"feedback_original_material")[0]
			button.remove_meta(&"feedback_original_material")
			button.remove_meta(&"feedback_tween"))


static func animate_panel(trigger: Control, panel: Control) -> void:
	trigger.visibility_changed.connect(_slide_panel.bind(trigger, panel, panel.offset_top))


static func _slide_panel(trigger: Control, panel: Control, resting_top: float) -> void:
	if panel.has_meta(&"panel_tween"):
		var previous: Tween = panel.get_meta(&"panel_tween")
		previous.kill()
	_set_panel_y(0.0, panel, resting_top)
	if not trigger.is_visible_in_tree():
		return
	var holder := panel.get_parent() as Control
	var travel := maxf(48.0, holder.size.y - panel.position.y)
	_set_panel_y(travel, panel, resting_top)
	var tween := panel.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	panel.set_meta(&"panel_tween", tween)
	tween.tween_method(_set_panel_y.bind(panel, resting_top), travel, 0.0, 0.20).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


static func _set_panel_y(shift: float, panel: Control, resting_top: float) -> void:
	var holder := panel.get_parent() as Control
	# 整块平移，分两次写锚点偏移会触发 Control 的最小尺寸限制。
	panel.position.y = holder.size.y * panel.anchor_top + resting_top + shift


static func shake_offset(progress: float, amplitude: float) -> Vector2:
	var t := progress * TAU
	return Vector2(sin(t * 4.0), sin(t * 5.0) * 0.62) * (1.0 - progress) * amplitude
