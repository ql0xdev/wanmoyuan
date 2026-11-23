extends RefCounted

# 地形独立于玩家（第 1 层）与怪物（第 2 层），不改变投射物命中规则。
const OBSTACLE_LAYER := 1 << 2


# 原来地面的 X/Z 分别对应 2D 的 X/Y；比例 1:1。
static func direction(angle: float) -> Vector2:
	return Vector2.from_angle(angle)
