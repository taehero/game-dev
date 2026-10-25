class_name OwnerProfile
extends RefCounted

const SCHEMA: Dictionary = {
	"staff_id": "int",
	"xp": "int",
	"skill_points": "int",
	"perks": "dict",
	"focus_dev_bp": "int",
}

var staff_id: int = -1
var xp: int = 0
var skill_points: int = 0
var perks: Dictionary[StringName, int] = {}
var focus_dev_bp: int = 10000


func to_dict() -> Dictionary:
	var perks_out: Dictionary = {}
	for k: StringName in perks:
		perks_out[String(k)] = perks[k]
	return {
		"staff_id": staff_id,
		"xp": xp,
		"skill_points": skill_points,
		"perks": perks_out,
		"focus_dev_bp": focus_dev_bp,
	}


static func from_dict(d: Dictionary) -> OwnerProfile:
	var o := OwnerProfile.new()
	o.staff_id = int(d["staff_id"])
	o.xp = int(d["xp"])
	o.skill_points = int(d["skill_points"])
	var pk: Dictionary = d["perks"]
	for k: StringName in GameState.sorted_names(pk):
		o.perks[k] = int(pk[String(k)])
	o.focus_dev_bp = int(d["focus_dev_bp"])
	return o
