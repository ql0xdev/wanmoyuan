extends RefCounted

const REALMS := {
	"qi_refining": {"name": "炼气", "rank": 0, "next": "foundation", "cost": 0, "power": 1.0, "speed": 1.0},
	"foundation": {"name": "筑基", "rank": 1, "next": "gold_core", "cost": 500, "power": 2.0, "speed": 1.1},
	"gold_core": {"name": "金丹", "rank": 2, "next": "nascent_soul", "cost": 2000, "power": 2.5, "speed": 1.1},
	"nascent_soul": {"name": "元婴", "rank": 3, "next": "spirit_transformation", "cost": 8000, "power": 3.0, "speed": 1.1},
	"spirit_transformation": {"name": "化神", "rank": 4, "next": "tribulation", "cost": 30000, "power": 3.5, "speed": 1.1},
	"tribulation": {"name": "渡劫", "rank": 5, "next": "", "cost": 100000, "power": 4.0, "speed": 1.1},
}
const BREAKTHROUGH_POINTS := 3
const ABYSSES := {
	"outer": {"name": "外渊", "realm": "qi_refining", "health": 1.0, "damage": 1.0, "density": 1.0,
		"boss": "魔尊·外相", "boss_health": 800, "boss_period": 1.0, "duration": 180,
		"tier": 0, "stones": 1, "color": Color.WHITE, "scale": 1.0,
		"wave_count": 15, "wave_golems": 0, "golem_at": 120, "crow_percent": 20},
	"middle": {"name": "中渊", "realm": "foundation", "health": 2.5, "damage": 2.0, "density": 1.2,
		"boss": "魔尊·筑基相", "boss_health": 2400, "boss_period": 1.0, "duration": 180,
		"tier": 1, "stones": 2, "color": Color("#5999e0"), "scale": 1.10,
		"wave_count": 18, "wave_golems": 0, "golem_at": 90, "crow_percent": 30},
	"inner": {"name": "内渊", "realm": "gold_core", "health": 6.0, "damage": 4.0, "density": 1.5,
		"boss": "魔尊·金丹相", "boss_health": 6400, "boss_period": 0.65, "duration": 180,
		"tier": 2, "stones": 4, "color": Color("#cd78dd"), "scale": 1.22,
		"wave_count": 20, "wave_golems": 0, "golem_at": 60, "crow_percent": 40},
	"deep": {"name": "渊底·幽域", "realm": "nascent_soul", "health": 15.0, "damage": 8.0, "density": 1.8,
		"boss": "魔尊·地相", "boss_health": 15000, "boss_period": 1.0, "duration": 240,
		"tier": 3, "stones": 8, "color": Color("#4f286d"), "scale": 1.10,
		"wave_count": 22, "wave_golems": 1, "golem_at": 45, "crow_percent": 45},
	"source": {"name": "渊底·魔源", "realm": "spirit_transformation", "health": 40.0, "damage": 16.0, "density": 2.2,
		"boss": "魔尊·天相", "boss_health": 32000, "boss_period": 1.0, "duration": 300,
		"tier": 4, "stones": 16, "color": Color("#460d1b"), "scale": 1.20,
		"wave_count": 25, "wave_golems": 2, "golem_at": 30, "crow_percent": 50,
		"bonus_drop": {"realm": "tribulation", "tier": 5}},
}
const DEFAULT_ABYSS := "outer"
enum Skill { SWORD, LIGHTNING, ORBS, ICE, HEAL, SWORD_STORM, FIRE, BLINK, DASH, WISP, BELL, SHIELD }
const SKILLS := ["sword", "lightning", "orbs", "ice", "heal", "sword_storm", "fire", "blink", "dash", "wisp", "bell", "shield"]
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
	"dash": {"name": "神行剑影", "cost": 1, "attack": true, "detail": "每 3 秒沿移动方向突进斩击，伤害 20/30/45",
		"interval": 3.0, "damage": [20, 30, 45], "distance": 215.0, "duration": 0.23, "radius": 26.0},
	"wisp": {"name": "幽冥鬼火", "cost": 2, "attack": true, "detail": "每 2.5 秒放出 1/2/3 团追踪鬼火，每团 18 伤害",
		"interval": 2.5, "damage": 18, "count": [1, 2, 3], "speed": 440.0, "lifetime": 1.9},
	"bell": {"name": "摄魂铃", "cost": 2, "attack": true, "detail": "每 6 秒震荡：300 范围减速 40% 两秒，伤害 15/25/40",
		"interval": 6.0, "damage": [15, 25, 40], "radius": 300.0, "slow": 0.40, "duration": 2.0},
	"shield": {"name": "玄龟护印", "cost": 2, "attack": false, "detail": "每 20 秒生成 30/50/80 点护盾，持续 5 秒",
		"interval": 20.0, "absorb": [30, 50, 80], "duration": 5.0},
}
const EVOLUTIONS := {
	"sword": {"name": "万剑归宗", "partner": "sword_storm", "card": "8 剑环绕并穿透\n每剑伤害 ×2.5",
		"count": 8, "power": 2.5},
	"lightning": {"name": "雷火天降", "partner": "fire", "card": "范围雷火\n感电＋灼烧",
		"interval": 3.0, "radius": 175.0, "amp": 0.20, "shock": 2.0, "burn_damage": 10, "burn_seconds": 3},
	"orbs": {"name": "玄武真罡", "passive": "body", "card": "罡气常驻\n减伤 30%\n反弹 50%",
		"mitigation": 0.30, "reflect": 0.50},
	"ice": {"name": "冰封万里", "passive": "spirit", "card": "每 8 秒冻结\n400 范围内敌人",
		"interval": 8.0, "radius": 400.0, "duration": 2.0},
	"heal": {"name": "生生不息", "passive": "any", "card": "回春效果翻倍\n受击回 2% 气血",
		"power": 2, "hit_heal": 0.02},
	"dash": {"name": "瞬影千杀", "passive": "wind", "card": "1.5 秒一次突进\n伤害 ×3，途中无敌",
		"interval": 1.5, "power": 3},
	"wisp": {"name": "九幽焚天", "passive": "focus", "card": "鬼火数量翻倍\n命中爆炸：范围伤 30",
		"count": 2, "blast_damage": 30, "radius": 95.0},
	"bell": {"name": "万魂噬心", "partner": "shield", "card": "500 范围减速 60%\n持续伤害 3 秒",
		"radius": 500.0, "slow": 0.60, "duration": 3.0, "dot_damage": 20},
	"shield": {"name": "玄武降世", "partner": "heal", "card": "护盾值 ×3\n持盾每秒回 3% 气血",
		"power": 3, "heal": 0.03},
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


static func realm_at_least(current: String, required: String) -> bool:
	return REALMS[current].rank >= REALMS[required].rank


static func evolution_matches(id: String, loadout: Array, passives: Dictionary) -> bool:
	if not EVOLUTIONS.has(id) or not loadout.has(id):
		return false
	var evolution: Dictionary = EVOLUTIONS[id]
	if evolution.has("partner"):
		return loadout.has(evolution.partner)
	if evolution.passive != "any":
		return passives.get(evolution.passive, 0) >= PASSIVES[evolution.passive].max
	for passive: String in PASSIVES:
		if passives.get(passive, 0) >= PASSIVES[passive].max:
			return true
	return false
