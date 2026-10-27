class_name Contract
extends RefCounted

enum Kind { PUBLISHING, OUTSOURCE, CONTRACT_WORK, ENGINE_LICENSE }

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
	"price": "int",
	"royalty_bp": "int",
	"target_points": "dict",
	"quality_roll": "int",
	"delivery_week": "int",
	"project_id": "int",
	"deliverable": "string",
	"features": "array",
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
var price: int = 0
var royalty_bp: int = 0
var target_points: Dictionary[StringName, int] = {}  # per point type
var quality_roll: int = 0  # 0-100
var delivery_week: int = -1
var project_id: int = -1
var deliverable: StringName = &""  # ENGINE_LICENSE: LicensedEngineDef id
var features: Array[StringName] = []  # OUTSOURCE: features of the outsourced engine


func to_dict() -> Dictionary:
	var tp_out: Dictionary = {}
	for k: StringName in target_points:
		tp_out[String(k)] = target_points[k]
	var features_out: Array = []
	for f: StringName in features:
		features_out.append(String(f))
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
		"price": price,
		"royalty_bp": royalty_bp,
		"target_points": tp_out,
		"quality_roll": quality_roll,
		"delivery_week": delivery_week,
		"project_id": project_id,
		"deliverable": String(deliverable),
		"features": features_out,
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
	c.price = int(d["price"])
	c.royalty_bp = int(d["royalty_bp"])
	var tp: Dictionary = d["target_points"]
	for k: StringName in GameState.sorted_names(tp):
		c.target_points[k] = int(tp[String(k)])
	c.quality_roll = int(d["quality_roll"])
	c.delivery_week = int(d["delivery_week"])
	c.project_id = int(d["project_id"])
	c.deliverable = StringName(String(d["deliverable"]))
	for f: Variant in d["features"]:
		c.features.append(StringName(String(f)))
	return c
