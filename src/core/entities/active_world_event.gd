class_name ActiveWorldEvent
extends RefCounted

const SCHEMA: Dictionary = {
	"event_id": "string",
	"start_week": "int",
	"end_week": "int",
}

var event_id: StringName
var start_week: int
var end_week: int


func to_dict() -> Dictionary:
	return {
		"event_id": String(event_id),
		"start_week": start_week,
		"end_week": end_week,
	}


static func from_dict(d: Dictionary) -> ActiveWorldEvent:
	var e := ActiveWorldEvent.new()
	e.event_id = StringName(String(d["event_id"]))
	e.start_week = int(d["start_week"])
	e.end_week = int(d["end_week"])
	return e
