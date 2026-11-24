extends Node2D

const Map = preload("res://scenes/cave/cave_map.gd")
const Station = preload("res://scenes/cave/cave_station.gd")
const ActorArt = preload("res://scenes/world/actor_art.gd")
const Joystick = preload("res://scenes/ui/virtual_joystick.gd")
const CaveMenu = preload("res://scenes/ui/cave_menu.gd")
const Look = preload("res://scenes/ui/ui_look.gd")

const MOVE_SPEED := 308.0
const INTERACT_DISTANCE := 80.0
const SPAWN := Vector2(520, 1714)
# The first six IDs follow the existing V6 tab order; the last is the portal.
const STATIONS := [
	Vector2(520, 332), Vector2(236, 446), Vector2(215, 875),
	Vector2(823, 1094), Vector2(804, 446), Vector2(215, 1422), Vector2(520, 1788),
]

@onready var _player: CharacterBody2D = $Actors/Player
@onready var _art: ActorArt = $Actors/Player/Art
@onready var _camera: Camera2D = $Actors/Player/Camera
@onready var _joystick: Joystick = $Overlay/Joystick
@onready var _hud: Control = $Overlay/SafeArea
@onready var _menu_button: Button = $Overlay/SafeArea/MenuButton
@onready var _hint: Label = $Overlay/SafeArea/Hint
@onready var _panels: CaveMenu = $Overlay/CaveMenu

var _stations: Array[Station] = []
var _touch_direction := Vector2.ZERO
var _stride := 0.0


func _ready() -> void:
	_player.position = SPAWN
	_art.radius = 25.0
	_art.facing = Vector2.UP
	_camera.limit_right = int(Map.EXTENT.x)
	_camera.limit_bottom = int(Map.EXTENT.y)
	_fit_camera()
	get_viewport().size_changed.connect(_fit_camera)
	Look.skin_button(_menu_button)
	if DisplayServer.is_touchscreen_available():
		_hint.text = "拖动移动　·　靠近物件后点击"
	_menu_button.pressed.connect(_open_world_menu)
	_panels.closed.connect(_resume_walking)
	_joystick.reserved_buttons.append(_menu_button)
	_joystick.direction_changed.connect(func(direction: Vector2) -> void: _touch_direction = direction)
	_joystick.reserved_button_tapped.connect(_tap_reserved)
	for id in range(STATIONS.size()):
		var station := Station.new()
		station.configure(id, STATIONS[id])
		$Actors.add_child(station)
		station.activated.connect(_open_station.bind(id))
		_joystick.reserved_buttons.append_array([station.bubble, station.hit_target])
		_stations.append(station)
	_update_proximity()


func _fit_camera() -> void:
	var view := get_viewport_rect().size / Map.EXTENT
	_camera.zoom = Vector2.ONE * maxf(1.0, maxf(view.x, view.y))
	_camera.reset_smoothing()


func _physics_process(_delta: float) -> void:
	if _panels.visible:
		return
	var direction := _touch_direction
	if direction == Vector2.ZERO:
		direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_player.velocity = direction * MOVE_SPEED
	_player.move_and_slide()
	if direction != Vector2.ZERO:
		_art.facing = direction.normalized()
	_update_proximity()


func _process(delta: float) -> void:
	var moving := _player.velocity.length_squared() > 1.0
	_stride += delta * (15.0 if moving else 7.0)
	var stretch := sin(_stride) * (0.06 if moving else 0.018)
	_art.scale = Vector2(1.0 + stretch, 1.0 - stretch * 0.65)
	_art.queue_redraw()


func _update_proximity() -> void:
	for station in _stations:
		station.set_near(_within_reach(station))


func _within_reach(station: Station) -> bool:
	return _player.position.distance_squared_to(station.position) <= INTERACT_DISTANCE * INTERACT_DISTANCE


func _tap_reserved(button: Control) -> void:
	# Touch is consumed by the floating joystick; mouse uses the same buttons via GUI.
	(button as Button).pressed.emit()


func _open_station(id: int) -> void:
	if _panels.visible or not _within_reach(_stations[id]):
		return
	_suspend_walking()
	if id == Station.Kind.PORTAL:
		_panels.open_portal()
	else:
		_panels.open_tab(id)


func _open_world_menu() -> void:
	if not _panels.visible:
		_suspend_walking()
		_panels.open_world_menu()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _panels.visible and event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_open_world_menu()


func _suspend_walking() -> void:
	_player.velocity = Vector2.ZERO
	_joystick.reset()
	_joystick.set_process_input(false)
	_hud.hide()
	for station in _stations:
		station.set_near(false)


func _resume_walking() -> void:
	_update_proximity()
	_hud.show()
	_joystick.set_process_input(true)
