extends Node2D

const Ink = preload("res://scenes/world/ink.gd")
enum Kind { PLAYER, WOLF, CROW, GOLEM, BOSS }

static var _mob_textures := {}

@export var kind := Kind.WOLF
var radius := 16.0
@export var tint := Color("#ee6b6d")
var facing := Vector2.RIGHT
var hit_white := false
var windup := false
var boss_fraction := 1.0
var boss_stage := 1


func _draw() -> void:
	if kind in [Kind.WOLF, Kind.CROW, Kind.GOLEM]:
		var texture := _mob_texture()
		if texture != null:
			var extent := Vector2.ONE * radius * 1.6
			draw_texture_rect(texture, Rect2(-extent, extent * 2.0), false)
			return
	var rim := Color.WHITE if hit_white else tint.lightened(0.46)
	var fill := Color("#e8fcff") if hit_white else tint
	var r := radius
	draw_circle(Vector2(0, 3.5), r + 4.0, Color("#090c12ac"), true, -1.0, true)
	if kind == Kind.PLAYER:
		draw_circle(Vector2.ZERO, r + 5.0, Ink.alpha(tint, 0.14), true, -1.0, true)
		draw_circle(Vector2.ZERO, r, fill.darkened(0.12), true, -1.0, true)
		Ink.ring(self, Vector2.ZERO, r, rim, 2.2)
		draw_arc(Vector2.ZERO, r * 0.67, -2.7, 0.75, 14, Ink.alpha(rim, 0.78), 2.0, true)
		Ink.diamond(self, Vector2.ZERO, Vector2(5.5, 7.5), Color("#e0fff2"), rim)
		var side := Vector2(-facing.y, facing.x)
		Ink.polygon(self, PackedVector2Array([facing * (r + 14), facing * (r + 4) + side * 5.5, facing * (r + 4) - side * 5.5]), rim, rim)
	elif kind == Kind.WOLF:
		draw_circle(Vector2.ZERO, r * 0.94, fill.darkened(0.18), true, -1.0, true)
		Ink.ring(self, Vector2.ZERO, r * 0.94, rim, 1.45)
		for sign_value in [-1, 1]:
			draw_circle(Vector2(r * 0.31, r * 0.34 * sign_value), 2.6, Color("#fff0d3"), true, -1.0, true)
	elif kind == Kind.CROW:
		var along := Vector2.RIGHT * r
		var side := Vector2.DOWN * r
		Ink.polygon(self, PackedVector2Array([along * 1.22, -along * 0.33 + side * 1.46,
			-along * 0.11 + side * 0.42, -along * 0.8, -along * 0.11 - side * 0.42,
			-along * 0.33 - side * 1.46]), fill.darkened(0.26), rim)
		Ink.diamond(self, along * 0.32, Vector2(3.8, 3.8), Color("#ffe0ff"), rim)
	elif kind == Kind.GOLEM:
		var q := r * 0.87
		Ink.polygon(self, PackedVector2Array([Vector2(-q, -q * 0.74), Vector2(-q * 0.74, -q), Vector2(q, -q),
			Vector2(q, q * 0.74), Vector2(q * 0.74, q), Vector2(-q, q)]), fill.darkened(0.29), rim, 2.2)
		Ink.diamond(self, Vector2.ZERO, Vector2(q * 0.45, q * 0.53), fill.darkened(0.12), rim)
		draw_polyline(PackedVector2Array([Vector2(-q, -q * 0.25), Vector2(-q * 0.50, -q * 0.37), Vector2(-q * 0.17, 0), Vector2(0, q)]), rim, 1.5, true)
	else:
		_draw_boss(r, fill, rim)


func _mob_texture() -> Texture2D:
	var key := "%d-%s-%s" % [kind, tint.to_html(false), hit_white]
	if _mob_textures.has(key):
		return _mob_textures[key]
	# 同种同品质色的怪共享同一张程序生成的贴图，保留各自的 Y 排序、旋转和闪白。
	var fill := Color("#e8fcff") if hit_white else tint
	var rim := Color.WHITE if hit_white else tint.lightened(0.46)
	var fill_color := "#" + fill.darkened(0.22).to_html(false)
	var rim_color := "#" + rim.to_html(false)
	var shadow := '<circle cx="0" cy=".18" r="1.12" fill="#090c12" opacity=".67"/>'
	var shape := ""
	match kind:
		Kind.WOLF:
			shape = ('<circle r=".95" fill="%s" stroke="%s" stroke-width=".11"/>'
				+ '<circle r="1.05" fill="none" stroke="%s" stroke-width=".14" opacity=".21"/>'
				+ '<circle cx=".31" cy="-.34" r=".155" fill="#fff0d3"/>'
				+ '<circle cx=".31" cy=".34" r=".155" fill="#fff0d3"/>') % [fill_color, rim_color, rim_color]
		Kind.CROW:
			shape = ('<path d="M 1.22 0 L -.33 1.46 L -.11 .42 L -.8 0 L -.11 -.42 L -.33 -1.46 Z" fill="%s" stroke="%s" stroke-width=".09" stroke-linejoin="round"/>'
				+ '<path d="M .32 -.22 L .54 0 L .32 .22 L .10 0 Z" fill="#ffe0ff"/>') % [fill_color, rim_color]
		Kind.GOLEM:
			shape = ('<path d="M -.87 -.64 L -.64 -.87 L .87 -.87 L .87 .64 L .64 .87 L -.87 .87 Z" fill="%s" stroke="%s" stroke-width=".07" stroke-linejoin="round"/>'
				+ '<path d="M 0 -.46 L .39 0 L 0 .46 L -.39 0 Z" fill="%s" fill-opacity=".55" stroke="%s" stroke-width=".045"/>'
				+ '<path d="M -.87 -.23 L -.47 -.33 L -.17 0 L 0 .87" fill="none" stroke="%s" stroke-width=".045"/>') % [
					fill_color, rim_color, "#" + fill.to_html(false), rim_color, rim_color]
	var image := Image.new()
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="-1.6 -1.6 3.2 3.2">%s%s</svg>' % [shadow, shape]
	if image.load_svg_from_string(svg) != OK:
		_mob_textures[key] = null
		return null
	var texture := ImageTexture.create_from_image(image)
	_mob_textures[key] = texture
	return texture


func _draw_boss(r: float, fill: Color, rim: Color) -> void:
	var edge := Color("#ffc39f") if windup else rim
	Ink.ring(self, Vector2.ZERO, r * 1.01, Ink.alpha(edge, 0.50), 2.2)
	var points := PackedVector2Array()
	for i in range(8):
		points.append(Vector2.from_angle(TAU * i / 8.0 + PI / 8.0) * r * 0.93)
	Ink.polygon(self, points, fill.darkened(0.36), edge, 2.6)
	Ink.diamond(self, Vector2.ZERO, Vector2(r * 0.49, r * 0.58), fill, edge)
	draw_circle(Vector2.ZERO, r * 0.14, Color("#fff0c5"), true, -1.0, true)
	for side in [-1, 1]:
		var x: float = r * 0.62 * side
		Ink.polygon(self, PackedVector2Array([Vector2(x * 0.63, -r * 0.18), Vector2(x * 1.48, -r * 0.96), Vector2(x, r * 0.22)]), fill, edge)
	if boss_fraction > 0.0:
		var bar := Rect2(-r * 1.06, -r - 15.0, r * 2.12, 7.0)
		draw_rect(bar.grow(2), Color("#151119"))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * boss_fraction, bar.size.y)), Color("#e36573"))
		draw_rect(bar, Ink.alpha(edge, 0.85), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(-r, -r - 19.0), ["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ"][boss_stage - 1],
			HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 18, Ink.GOLD)
