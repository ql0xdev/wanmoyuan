extends Node3D

const Player = preload("res://scenes/player.gd")
const Equipment = preload("res://scripts/equipment_catalog.gd")
const BEAM_SHADER := preload("res://scenes/effects/loot_beam.gdshader")
const COLLECT_RADIUS := 64.0
const LANDING_TIME := 0.12

signal collected(pickup: Node3D, item: Dictionary)

static var _marker_materials: Array[StandardMaterial3D] = []
static var _glow_materials: Array[ShaderMaterial] = []

@onready var _marker: MeshInstance3D = $Marker
@onready var _glow: MeshInstance3D = $Glow

var display_name := ""
var quality_color := Color.WHITE
var _item: Dictionary
var _target: Player
var _landing_left := 0.0


func _ready() -> void:
	if not _marker_materials.is_empty():
		return
	for quality in range(Equipment.COLORS.size()):
		var ink: Color = Equipment.COLORS[quality]
		var marker := StandardMaterial3D.new()
		marker.albedo_color = ink
		marker.roughness = 0.85
		if quality > 0:
			marker.emission_enabled = true
			marker.emission = ink
			marker.emission_energy_multiplier = 0.55
		_marker_materials.append(marker)
		if quality == 0:
			_glow_materials.append(null)
		else:
			var beam := ShaderMaterial.new()
			beam.shader = BEAM_SHADER
			beam.set_shader_parameter("tint", ink)
			_glow_materials.append(beam)


func drop(at: Vector3, target: Player, item: Dictionary) -> void:
	global_position = at
	_item = item
	_target = target
	_landing_left = LANDING_TIME
	var quality: int = item.quality
	display_name = Equipment.title(item)
	quality_color = Equipment.COLORS[quality]
	_marker.material_override = _marker_materials[quality]
	_glow.material_override = _glow_materials[quality]
	_glow.visible = quality > 0


func name_anchor() -> Vector3:
	return global_position + Vector3.UP * (92.0 if _glow.visible else 48.0)


func _physics_process(delta: float) -> void:
	if _target == null or not _target.is_alive():
		return
	_landing_left = maxf(0.0, _landing_left - delta)
	if _landing_left > 0.0 or global_position.distance_squared_to(_target.global_position) > COLLECT_RADIUS * COLLECT_RADIUS:
		return
	var item := _item
	_item = {}
	_target = null
	collected.emit(self, item)
