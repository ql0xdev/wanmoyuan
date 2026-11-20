extends Control

const CORNER_PADDING := 20.0
const MIN_LAYOUT_SIZE := Vector2(696.0, 420.0)
const REFRESH_INTERVAL := 0.25

var _mobile := OS.has_feature("android") or OS.has_feature("ios")
var _refresh_left := 0.0


func _ready() -> void:
	get_viewport().size_changed.connect(_refresh_layout)
	_refresh_layout()
	set_process(_mobile)


func _process(delta: float) -> void:
	# 安全区可能在系统栏变化或从后台回来时更新，而视口大小不一定改变。
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = REFRESH_INTERVAL
		_refresh_layout()


func _refresh_layout() -> void:
	var viewport := get_viewport()
	var available := viewport.get_visible_rect()
	if _mobile:
		available = local_safe_rect(
			available, DisplayServer.get_display_safe_area(), viewport.get_screen_transform()
		)
	_fit_content(available)


static func local_safe_rect(view: Rect2, display_safe: Rect2i, viewport_to_screen: Transform2D) -> Rect2:
	# 系统接口返回物理像素，转换到 stretch 后的逻辑坐标，再与当前视口取交集。
	var available := view
	if display_safe.has_area():
		var screen_to_view := viewport_to_screen.affine_inverse()
		var safe := (screen_to_view * Rect2(display_safe)).intersection(view)
		if safe.has_area():
			available = safe
	# 没有挖孔的圆角屏也保留一点边距，避免贴边按钮或摇杆被裁掉。
	var padding := minf(CORNER_PADDING, minf(available.size.x, available.size.y) * 0.1)
	return available.grow(-padding)


func _fit_content(available: Rect2) -> void:
	if not available.has_area():
		return
	# 窄安全区等比缩放，保证三张功法卡牌都能完整显示和点击。
	var fit := minf(1.0, minf(available.size.x / MIN_LAYOUT_SIZE.x, available.size.y / MIN_LAYOUT_SIZE.y))
	position = available.position
	size = available.size / fit
	scale = Vector2.ONE * fit
