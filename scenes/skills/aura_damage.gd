extends RefCounted

const Enemy = preload("res://scenes/enemies/enemy.gd")
const DamageBatch = preload("res://scenes/skills/damage_batch.gd")
const INTERVAL := 0.5
const POWER := 0.60
const EPSILON := 0.000001

var _inside := {}
var _next := {}


static func tick_amount(original_damage: int) -> int:
	return roundi(original_damage * POWER)


func clear() -> void:
	_inside.clear()
	_next.clear()


func step(delta: float, origin: Vector2, radius: float, amount: int, enemies: Array[Enemy], batch: DamageBatch) -> bool:
	var ticked := false
	var radius_squared := radius * radius
	_next.clear()
	batch.begin()
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		if origin.distance_squared_to(enemy.global_position) > radius_squared:
			continue
		var id := enemy.get_instance_id()
		var prior: Vector2 = _inside.get(id, Vector2(-1, 0))
		var elapsed := prior.y + delta if int(prior.x) == enemy.spawn_id else 0.0
		while elapsed + EPSILON >= INTERVAL and enemy._health > 0:
			elapsed -= INTERVAL
			enemy.take_damage(amount)
			ticked = true
		if enemy._health > 0:
			_next[id] = Vector2(enemy.spawn_id, elapsed)
	batch.finish()
	var previous := _inside
	_inside = _next
	_next = previous
	return ticked
