extends RefCounted

const REALMS := {
	"qi_refining": {"name": "炼气", "rank": 0, "next": "foundation", "cost": 0, "power": 1.0, "speed": 1.0},
	"foundation": {"name": "筑基", "rank": 1, "next": "gold_core", "cost": 500, "power": 2.0, "speed": 1.1},
	"gold_core": {"name": "金丹", "rank": 2, "next": "", "cost": 2000, "power": 2.5, "speed": 1.1},
}
const ABYSSES := {
	"outer": {"name": "外渊", "realm": "qi_refining", "health": 1.0, "damage": 1.0, "density": 1.0, "boss": "魔尊·外相", "boss_health": 1.0, "boss_period": 1.0, "tier": 0, "stones": 1, "color": Color.WHITE, "scale": 1.0},
	"middle": {"name": "中渊", "realm": "foundation", "health": 2.5, "damage": 2.0, "density": 1.2, "boss": "魔尊·筑基相", "boss_health": 3.0, "boss_period": 1.0, "tier": 1, "stones": 2, "color": Color("#5999e0"), "scale": 1.10},
	"inner": {"name": "内渊", "realm": "gold_core", "health": 6.0, "damage": 4.0, "density": 1.5, "boss": "魔尊·金丹相", "boss_health": 8.0, "boss_period": 0.65, "tier": 2, "stones": 4, "color": Color("#cd78dd"), "scale": 1.22},
}
const DEFAULT_ABYSS := "outer"
enum Skill { SWORD, LIGHTNING, ORBS, ICE, HEAL, SWORD_STORM, FIRE, BLINK, MAX_HEALTH }
const SKILLS := ["sword", "lightning", "orbs", "ice", "heal", "sword_storm", "fire", "blink"]
const STARTER_SKILLS := ["sword", "lightning", "orbs", "ice", "heal"]
const DEFAULT_LOADOUT := ["sword", "lightning", "orbs", "ice"]
const MAX_LOADOUT := 4
const SKILL_DATA := {
	"sword": {"name": "御剑术", "cost": 0, "attack": true, "detail": "飞剑自动追击最近的敌人"},
	"lightning": {"name": "雷诀", "cost": 0, "attack": true, "detail": "向随机敌人落下范围雷击"},
	"orbs": {"name": "护体罡气", "cost": 0, "attack": true, "detail": "环绕火珠接触敌人时造成伤害"},
	"ice": {"name": "冰心咒", "cost": 0, "attack": false, "detail": "减速附近敌人"},
	"heal": {"name": "回春功", "cost": 0, "attack": false, "detail": "周期性恢复气血"},
	"sword_storm": {"name": "万剑诀", "cost": 2, "attack": true, "detail": "每 5 秒向四周射出 8 把飞剑，每把 15 伤害"},
	"fire": {"name": "离火印", "cost": 2, "attack": true, "detail": "每 4 秒在敌人脚下生火，持续 3 秒，每秒 12 伤害"},
	"blink": {"name": "缩地成寸", "cost": 1, "attack": false, "detail": "受击时有 10% 概率瞬移 300 像素"},
}
const PASSIVES := {
	"body": {"name": "锻体诀", "stat": "health_flat", "amount": 15.0, "max": 5, "detail": "每级气血上限 +15"},
	"spirit": {"name": "御灵诀", "stat": "damage", "amount": 0.06, "max": 5, "detail": "每级全伤害 +6%"},
	"wind": {"name": "风行诀", "stat": "move_speed", "amount": 0.04, "max": 3, "detail": "每级移速 +4%"},
	"fortune": {"name": "聚宝诀", "stat": "stone_amount", "amount": 0.10, "max": 3, "detail": "每级灵石掉落 +10%"},
	"focus": {"name": "凝神诀", "stat": "cooldown", "amount": 0.04, "max": 3, "detail": "每级冷却缩减 +4%"},
}


static func first_attack(loadout: Array) -> String:
	for skill: Variant in loadout:
		if skill is String and SKILL_DATA.get(skill, {}).get("attack", false):
			return skill
	return ""
