extends RefCounted

signal resolved(kills: int)

var _depth := 0
var _kills := 0


func begin() -> void:
	_depth += 1


func record_kill() -> void:
	if _depth > 0:
		_kills += 1


func finish() -> void:
	_depth -= 1
	if _depth == 0:
		var count := _kills
		_kills = 0
		if count > 0:
			resolved.emit(count)
