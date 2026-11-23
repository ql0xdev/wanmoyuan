extends Node2D

const Player = preload("res://scenes/player.gd")
const Equipment = preload("res://scripts/equipment_catalog.gd")
const Art = preload("res://scenes/pickups/pickup_art.gd")
const COLLECT_RADIUS := 64.0
const LANDING_TIME := 0.12

signal collected(pickup: Node2D, item: Dictionary)

@onready var _ink: Node2D = $Ink
@onready var _marker: Art = $Ink/Marker
@onready var _glow: Art = $Ink/Glow

var display_name := ""
var quality_color := Color.WHITE
var _item: Dictionary
var _target: Player
var _landing_left := 0.0
var _reveal_left := 0.0


func drop(at: Vector2, target: Player, item: Dictionary, reveal_delay := 0.0) -> void:
	global_position = at
	_item = item
	_target = target
	_landing_left = LANDING_TIME
	_reveal_left = reveal_delay
	var quality: int = item.quality
	display_name = Equipment.title(item)
	quality_color = Equipment.COLORS[quality]
	_marker.tint = quality_color
	_glow.tint = quality_color
	_marker.queue_redraw()
	_glow.queue_redraw()
	_glow.visible = quality > 0
	_ink.visible = _reveal_left <= 0.0


func name_anchor() -> Vector2:
	return global_position + Vector2.UP * (97.0 if _glow.visible else 19.0)


func _physics_process(delta: float) -> void:
	if _reveal_left > 0.0:
		_reveal_left -= delta
		if _reveal_left <= 0.0:
			_ink.show()
	if _target == null or not _target.is_alive():
		return
	_landing_left = maxf(0.0, _landing_left - delta)
	if _landing_left > 0.0 or global_position.distance_squared_to(_target.global_position) > COLLECT_RADIUS * COLLECT_RADIUS:
		return
	var item := _item
	_item = {}
	_target = null
	collected.emit(self, item)
