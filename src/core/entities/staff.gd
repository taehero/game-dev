class_name Staff
extends RefCounted

enum Role { NONE, LEAD_DESIGN, LEAD_TECH, LEAD_ART, MEMBER }

const SCHEMA: Dictionary = {
	"id": "int",
	"company_id": "int",
	"name": "string",
	"skills": "dict",
	"traits": "array",
	"morale": "int",
	"burnout": "int",
	"salary": "int",
	"assigned_project_id": "int",
	"role": "string",
}

var id: int
var company_id: int
var name: String
var skills: Dictionary[StringName, int] = {}  # keys: design, tech, art, audio
var traits: Array[StringName] = []
var morale: int = 70
var burnout: int = 0
var salary: int = 0
var assigned_project_id: int = -1
var role: Role = Role.NONE


func to_dict() -> Dictionary:
	var skills_out: Dictionary = {}
	for k: StringName in skills:
		skills_out[String(k)] = skills[k]
	var traits_out: Array = []
	for t: StringName in traits:
		traits_out.append(String(t))
	return {
		"id": id,
		"company_id": company_id,
		"name": name,
		"skills": skills_out,
		"traits": traits_out,
		"morale": morale,
		"burnout": burnout,
		"salary": salary,
		"assigned_project_id": assigned_project_id,
		"role": Role.keys()[role],
	}


static func from_dict(d: Dictionary) -> Staff:
	var s := Staff.new()
	s.id = int(d["id"])
	s.company_id = int(d["company_id"])
	s.name = String(d["name"])
	var sk: Dictionary = d["skills"]
	for k: Variant in sk:
		s.skills[StringName(String(k))] = int(sk[k])
	for t: Variant in d["traits"]:
		s.traits.append(StringName(String(t)))
	s.morale = int(d["morale"])
	s.burnout = int(d["burnout"])
	s.salary = int(d["salary"])
	s.assigned_project_id = int(d["assigned_project_id"])
	s.role = Role[String(d["role"])]
	return s
