class_name Staff
extends RefCounted

enum Role { NONE, LEAD_DESIGN, LEAD_TECH, LEAD_ART, MEMBER }
enum Level { JUNIOR, MID, SENIOR, LEAD, MANAGER, EXECUTIVE }

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
	"exp": "dict",
	"seat_index": "int",
	"last_raise_week": "int",
	"asking_raise": "int",
	"is_owner": "bool",
	"level": "string",
	"title": "string",
	"hired_week": "int",
	"week_points": "dict",
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
var exp: Dictionary[StringName, int] = {}
var seat_index: int = -1
var last_raise_week: int = 0
var asking_raise: int = 0
var is_owner: bool = false
var level: Level = Level.JUNIOR
var title: StringName = &""
var hired_week: int = 0
var week_points: Dictionary[StringName, int] = {}  # points produced in the latest Production step


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
		"exp": _ints_out(exp),
		"seat_index": seat_index,
		"last_raise_week": last_raise_week,
		"asking_raise": asking_raise,
		"is_owner": is_owner,
		"level": Level.keys()[level],
		"title": String(title),
		"hired_week": hired_week,
		"week_points": _ints_out(week_points),
	}


static func from_dict(d: Dictionary) -> Staff:
	var s := Staff.new()
	s.id = int(d["id"])
	s.company_id = int(d["company_id"])
	s.name = String(d["name"])
	var sk: Dictionary = d["skills"]
	for k: StringName in GameState.sorted_names(sk):
		s.skills[k] = int(sk[String(k)])
	for t: Variant in d["traits"]:
		s.traits.append(StringName(String(t)))
	s.morale = int(d["morale"])
	s.burnout = int(d["burnout"])
	s.salary = int(d["salary"])
	s.assigned_project_id = int(d["assigned_project_id"])
	s.role = Role[String(d["role"])]
	var ex: Dictionary = d["exp"]
	for k: StringName in GameState.sorted_names(ex):
		s.exp[k] = int(ex[String(k)])
	s.seat_index = int(d["seat_index"])
	s.last_raise_week = int(d["last_raise_week"])
	s.asking_raise = int(d["asking_raise"])
	s.is_owner = bool(d["is_owner"])
	s.level = Level[String(d["level"])]
	s.title = StringName(String(d["title"]))
	s.hired_week = int(d["hired_week"])
	var wp: Dictionary = d["week_points"]
	for k: StringName in GameState.sorted_names(wp):
		s.week_points[k] = int(wp[String(k)])
	return s


static func _ints_out(src: Dictionary[StringName, int]) -> Dictionary:
	var out: Dictionary = {}
	for k: StringName in src:
		out[String(k)] = src[k]
	return out
