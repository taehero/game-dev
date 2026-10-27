class_name Company
extends RefCounted

enum Kind { PLAYER, AI_DEVELOPER, AI_PUBLISHER, BANK, LENDER, VENDOR }

const SCHEMA: Dictionary = {
	"id": "int",
	"name": "string",
	"kind": "string",
	"money": "int",
	"reputation": "int",
	"fan_count": "int",
	"office_id": "string",
	"research_points": "int",
	"unlocked": "array",
	"dev_kits": "array",
	"months_negative": "int",
	"awards": "array",
	"last_missed_week": "int",
}

var id: int
var name: String
var kind: Kind = Kind.PLAYER
var money: int = 0
var reputation: int = 0  # 0-100
var fan_count: int = 0
var office_id: StringName = &""
var research_points: int = 0
var unlocked: Array[StringName] = []
var dev_kits: Array[StringName] = []
var months_negative: int = 0
var awards: Array[StringName] = []
var last_missed_week: int = -1  # last week a loan payment was missed; -1 = never



func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"kind": Kind.keys()[kind],
		"money": money,
		"reputation": reputation,
		"fan_count": fan_count,
		"office_id": String(office_id),
		"research_points": research_points,
		"unlocked": _names_out(unlocked),
		"dev_kits": _names_out(dev_kits),
		"months_negative": months_negative,
		"awards": _names_out(awards),
		"last_missed_week": last_missed_week,
	}


static func from_dict(d: Dictionary) -> Company:
	var c := Company.new()
	c.id = int(d["id"])
	c.name = String(d["name"])
	c.kind = Kind[String(d["kind"])]
	c.money = int(d["money"])
	c.reputation = int(d["reputation"])
	c.fan_count = int(d["fan_count"])
	c.office_id = StringName(String(d["office_id"]))
	c.research_points = int(d["research_points"])
	for u: Variant in d["unlocked"]:
		c.unlocked.append(StringName(String(u)))
	for k: Variant in d["dev_kits"]:
		c.dev_kits.append(StringName(String(k)))
	c.months_negative = int(d["months_negative"])
	for a: Variant in d["awards"]:
		c.awards.append(StringName(String(a)))
	c.last_missed_week = int(d["last_missed_week"])
	return c


static func _names_out(names: Array[StringName]) -> Array:
	var out: Array = []
	for n: StringName in names:
		out.append(String(n))
	return out
