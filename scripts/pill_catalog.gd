extends RefCounted

const ITEMS := {
	"heal": {"name": "回血丹", "cost": 50, "detail": "立即回复气血上限的 50%"},
	"rage": {"name": "狂暴丹", "cost": 100, "detail": "本局攻击 +30%"},
	"guard": {"name": "护身丹", "cost": 100, "detail": "本局受伤减免 20%"},
	"fortune": {"name": "聚宝丹", "cost": 150, "detail": "本局灵石掉落 +50%"},
}


static func unavailable_reason(id: String, stones: int, health: int, maximum: int, used: bool) -> String:
	if used:
		return "已服用"
	if id == "heal" and health >= maximum:
		return "气血已满"
	if stones < ITEMS[id].cost:
		return "灵石不足"
	return ""
