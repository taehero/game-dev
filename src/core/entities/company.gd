class_name Company
extends RefCounted

enum Kind { PLAYER, AI_DEVELOPER, AI_PUBLISHER }

const SCHEMA: Dictionary = {
	"id": "int",
	"name": "string",
	"kind": "string",
	"money": "int",
	"reputation": "int",
	"fan_count": "int",
}

var id: int
var name: String
var kind: Kind = Kind.PLAYER
var money: int = 0
var reputation: int = 0  # 0-100
var fan_count: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"kind": Kind.keys()[kind],
		"money": money,
		"reputation": reputation,
		"fan_count": fan_count,
	}


static func from_dict(d: Dictionary) -> Company:
	var c := Company.new()
	c.id = int(d["id"])
	c.name = String(d["name"])
	c.kind = Kind[String(d["kind"])]
	c.money = int(d["money"])
	c.reputation = int(d["reputation"])
	c.fan_count = int(d["fan_count"])
	return c
