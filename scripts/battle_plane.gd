extends RefCounted

# 地形独立于玩家（第 1 层）与怪物（第 2 层），不改变投射物命中规则。
const OBSTACLE_LAYER := 1 << 2


# 地面上 1 个 3D 单位对应 V2 的 1 像素；模型高度不参与碰撞或距离计算。
static func direction(angle: float) -> Vector3:
	return Vector3(cos(angle), 0.0, sin(angle))


static func from_input(input: Vector2) -> Vector3:
	return Vector3(input.x, 0.0, input.y)
