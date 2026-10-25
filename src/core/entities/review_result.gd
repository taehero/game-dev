class_name ReviewResult
extends RefCounted

const SCHEMA: Dictionary = {
	"outlet_id": "string",
	"score_x10": "int",
	"strength_key": "string",
	"weakness_key": "string",
}

var outlet_id: StringName = &""
var score_x10: int = 0
var strength_key: StringName = &""
var weakness_key: StringName = &""


func to_dict() -> Dictionary:
	return {
		"outlet_id": String(outlet_id),
		"score_x10": score_x10,
		"strength_key": String(strength_key),
		"weakness_key": String(weakness_key),
	}


static func from_dict(d: Dictionary) -> ReviewResult:
	var r := ReviewResult.new()
	r.outlet_id = StringName(String(d["outlet_id"]))
	r.score_x10 = int(d["score_x10"])
	r.strength_key = StringName(String(d["strength_key"]))
	r.weakness_key = StringName(String(d["weakness_key"]))
	return r
