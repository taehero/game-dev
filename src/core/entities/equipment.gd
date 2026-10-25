class_name Equipment
extends RefCounted

enum Ownership { BOUGHT, LEASED }

const SCHEMA: Dictionary = {
	"id": "int",
	"company_id": "int",
	"def_id": "string",
	"ownership": "string",
	"seat_index": "int",
	"bought_week": "int",
	"value": "int",
}

var id: int
var company_id: int
var def_id: StringName = &""
var ownership: Ownership = Ownership.BOUGHT
var seat_index: int = -1
var bought_week: int = 0
var value: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"company_id": company_id,
		"def_id": String(def_id),
		"ownership": Ownership.keys()[ownership],
		"seat_index": seat_index,
		"bought_week": bought_week,
		"value": value,
	}


static func from_dict(d: Dictionary) -> Equipment:
	var e := Equipment.new()
	e.id = int(d["id"])
	e.company_id = int(d["company_id"])
	e.def_id = StringName(String(d["def_id"]))
	e.ownership = Ownership[String(d["ownership"])]
	e.seat_index = int(d["seat_index"])
	e.bought_week = int(d["bought_week"])
	e.value = int(d["value"])
	return e
