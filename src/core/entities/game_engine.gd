class_name GameEngine
extends RefCounted

enum Source { BUILT, OUTSOURCED }

const SCHEMA: Dictionary = {
	"id": "int",
	"company_id": "int",
	"name": "string",
	"features": "array",
	"tech_cap": "int",
	"source": "string",
	"built_week": "int",
}

var id: int
var company_id: int
var name: String
var features: Array[StringName] = []
var tech_cap: int = 0
var source: Source = Source.BUILT
var built_week: int = 0


func to_dict() -> Dictionary:
	var features_out: Array = []
	for f: StringName in features:
		features_out.append(String(f))
	return {
		"id": id,
		"company_id": company_id,
		"name": name,
		"features": features_out,
		"tech_cap": tech_cap,
		"source": Source.keys()[source],
		"built_week": built_week,
	}


static func from_dict(d: Dictionary) -> GameEngine:
	var g := GameEngine.new()
	g.id = int(d["id"])
	g.company_id = int(d["company_id"])
	g.name = String(d["name"])
	for f: Variant in d["features"]:
		g.features.append(StringName(String(f)))
	g.tech_cap = int(d["tech_cap"])
	g.source = Source[String(d["source"])]
	g.built_week = int(d["built_week"])
	return g
