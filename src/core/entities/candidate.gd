class_name Candidate
extends RefCounted

const SCHEMA: Dictionary = {
	"id": "int",
	"name": "string",
	"skills": "dict",
	"traits": "array",
	"asking_salary": "int",
	"expires_week": "int",
	"level": "int",
}

var id: int
var name: String
var skills: Dictionary[StringName, int] = {}
var traits: Array[StringName] = []
var asking_salary: int = 0
var expires_week: int = 0
var level: int = 0  # a Staff.Level value, stored as int


func to_dict() -> Dictionary:
	var skills_out: Dictionary = {}
	for k: StringName in skills:
		skills_out[String(k)] = skills[k]
	var traits_out: Array = []
	for t: StringName in traits:
		traits_out.append(String(t))
	return {
		"id": id,
		"name": name,
		"skills": skills_out,
		"traits": traits_out,
		"asking_salary": asking_salary,
		"expires_week": expires_week,
		"level": level,
	}


static func from_dict(d: Dictionary) -> Candidate:
	var c := Candidate.new()
	c.id = int(d["id"])
	c.name = String(d["name"])
	var sk: Dictionary = d["skills"]
	for k: StringName in GameState.sorted_names(sk):
		c.skills[k] = int(sk[String(k)])
	for t: Variant in d["traits"]:
		c.traits.append(StringName(String(t)))
	c.asking_salary = int(d["asking_salary"])
	c.expires_week = int(d["expires_week"])
	c.level = int(d["level"])
	return c
