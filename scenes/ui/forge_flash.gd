extends Control

const Look = preload("res://scenes/ui/ui_look.gd")
const SHADER := preload("res://scenes/ui/breakthrough_flash.gdshader")
var _ink: ColorRect
var _caption: Label
var _tween: Tween


func _ready() -> void:
	z_index = 14
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ink = ColorRect.new()
	_ink.mouse_filter = MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	_ink.material = mat
	add_child(_ink)
	_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption = Label.new()
	_caption.mouse_filter = MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 64)
	_caption.add_theme_color_override("font_color", Look.GOLD)
	_caption.add_theme_color_override("font_outline_color", Look.BACKGROUND)
	_caption.add_theme_constant_override("outline_size", 10)
	add_child(_caption)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hide()


func flash(caption: String) -> void:
	if _tween != null:
		_tween.kill()
	_caption.text = caption
	_ink.modulate.a = 0.65
	_caption.modulate.a = 1.0
	show()
	_tween = create_tween().set_parallel()
	_tween.tween_property(_ink, "modulate:a", 0.0, 0.48)
	_tween.tween_property(_caption, "modulate:a", 0.0, 0.28).set_delay(0.80)
	_tween.chain().tween_callback(hide)
