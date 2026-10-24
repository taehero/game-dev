class_name Contract
extends RefCounted

enum Kind { PUBLISHING }

const SCHEMA: Dictionary = {
	"id": "int",
	"kind": "string",
	"party_a": "int",
	"party_b": "int",
	"advance": "int",
	"revenue_share_pct": "int",
	"deadline_week": "int",
	"late_penalty_per_week": "int",
	"locked_genre": "string",
	"locked_platform": "string",
	"min_score": "int",
}

var id: int
var kind: Kind = Kind.PUBLISHING
var party_a: int
var party_b: int
var advance: int = 0
var revenue_share_pct: int = 0
var deadline_week: int = 0
var late_penalty_per_week: int = 0
var locked_genre: StringName = &""
var locked_platform: StringName = &""
var min_score: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"kind": Kind.keys()[kind],
		"party_a": party_a,
		"party_b": party_b,
		"advance": advance,
		"revenue_share_pct": revenue_share_pct,
		"deadline_week": deadline_week,
		"late_penalty_per_week": late_penalty_per_week,
		"locked_genre": String(locked_genre),
		"locked_platform": String(locked_platform),
		"min_score": min_score,
	}


static func from_dict(d: Dictionary) -> Contract:
	var c := Contract.new()
	c.id = int(d["id"])
	c.kind = Kind[String(d["kind"])]
	c.party_a = int(d["party_a"])
	c.party_b = int(d["party_b"])
	c.advance = int(d["advance"])
	c.revenue_share_pct = int(d["revenue_share_pct"])
	c.deadline_week = int(d["deadline_week"])
	c.late_penalty_per_week = int(d["late_penalty_per_week"])
	c.locked_genre = StringName(String(d["locked_genre"]))
	c.locked_platform = StringName(String(d["locked_platform"]))
	c.min_score = int(d["min_score"])
	return c
