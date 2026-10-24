class_name Decision
extends RefCounted

const SCHEMA: Dictionary = {
	"id": "int",
	"kind": "string",
	"related_ids": "array",
	"deadline_week": "int",
	"option_keys": "array",
}

var id: int
var kind: StringName
var related_ids: Array[int] = []
var deadline_week: int
var option_keys: Array[StringName] = []


func to_dict() -> Dictionary:
	var related_out: Array = []
	for r: int in related_ids:
		related_out.append(r)
	var options_out: Array = []
	for o: StringName in option_keys:
		options_out.append(String(o))
	return {
		"id": id,
		"kind": String(kind),
		"related_ids": related_out,
		"deadline_week": deadline_week,
		"option_keys": options_out,
	}


static func from_dict(d: Dictionary) -> Decision:
	var dec := Decision.new()
	dec.id = int(d["id"])
	dec.kind = StringName(String(d["kind"]))
	for r: Variant in d["related_ids"]:
		dec.related_ids.append(int(r))
	dec.deadline_week = int(d["deadline_week"])
	for o: Variant in d["option_keys"]:
		dec.option_keys.append(StringName(String(o)))
	return dec
