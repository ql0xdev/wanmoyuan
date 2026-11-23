extends RefCounted

const STAT_CARDS := {
	"damage": {"name": "攻击强化", "caption": "攻击", "amount": 0.05, "percent": true},
	"health_flat": {"name": "气血强化", "caption": "气血上限", "amount": 20, "percent": false},
	"move_speed": {"name": "身法强化", "caption": "移速", "amount": 0.04, "percent": true},
	"cooldown": {"name": "凝神", "caption": "冷却缩减", "amount": 0.04, "percent": true},
	"magnet": {"name": "拾遗", "caption": "拾取范围", "amount": 0.10, "percent": true},
	"kill_heal": {"name": "嗜血", "caption": "击杀回血", "amount": 2, "percent": false},
	"stone_amount": {"name": "聚宝", "caption": "灵石掉落", "amount": 0.08, "percent": true},
	"mitigation": {"name": "铁壁", "caption": "受伤减免", "amount": 0.03, "percent": true},
}
const RARE_PERCENT := 8


static func stat_card_text(id: String, rare: bool) -> String:
	var stat: Dictionary = STAT_CARDS[id]
	var amount: float = stat.amount * (2 if rare else 1)
	return "%s · %s\n\n%s +%d%s" % ["珍稀" if rare else "属性", stat.name, stat.caption,
		roundi(amount * (100 if stat.percent else 1)), "%" if stat.percent else ""]
