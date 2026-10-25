class_name Project
extends RefCounted

enum Phase { CONCEPT, PRODUCTION, POLISH, RELEASED, LIVE, RETIRED }
enum Kind { GAME, ENGINE, CONTRACT_WORK }

const WEEKLY_UNITS_CAP: int = 104
## Nine slider shares in bp: stage 1 Code/Design/Story, stage 2 Levels/Characters/AI,
## stage 3 Graphics/Audio/Balance. Each consecutive triple sums to 10000.
const DEFAULT_FOCUS: Array[int] = [3334, 3333, 3333, 3334, 3333, 3333, 3334, 3333, 3333]

const SCHEMA: Dictionary = {
	"id": "int",
	"company_id": "int",
	"title": "string",
	"config": "dict",
	"phase": "string",
	"stage_index": "int",
	"stage_progress": "int",
	"focus": "array",
	"points": "dict",
	"bugs": "int",
	"hype": "int",
	"deadline_week": "int",
	"crunch": "bool",
	"delay_weeks_total": "int",
	"contract_id": "int",
	"release_week": "int",
	"units_sold": "int",
	"revenue": "int",
	"user_score": "int",
	"sentiment": "int",
	"kind": "string",
	"size_id": "string",
	"engine_id": "int",
	"features": "array",
	"review_results": "array",
	"weekly_units": "array",
	"promo_until_week": "int",
	"promo_discount_bp": "int",
	"mod_tools": "bool",
	"dlc_count": "int",
}

var id: int
var company_id: int
var title: String
var config: Dictionary[StringName, StringName] = {}  # platform, engine, genre, topic, art_style, business_model
var phase: Phase = Phase.CONCEPT
var stage_index: int = 0
var stage_progress: int = 0  # bp, 0-10000
var focus: Array[int] = DEFAULT_FOCUS.duplicate()  # nine slider shares in bp
var points: Dictionary[StringName, int] = {}  # design, tech, art, audio
var bugs: int = 0
var hype: int = 0
var deadline_week: int
var crunch: bool = false
var delay_weeks_total: int = 0
var contract_id: int = -1
var release_week: int = -1
var units_sold: int = 0
var revenue: int = 0
var user_score: int = 0
var sentiment: int = 0
var kind: Kind = Kind.GAME
var size_id: StringName = &""
var engine_id: int = -1
var features: Array[StringName] = []
var review_results: Array[ReviewResult] = []
var weekly_units: Array[int] = []
var promo_until_week: int = -1
var promo_discount_bp: int = 0
var mod_tools: bool = false
var dlc_count: int = 0


func to_dict() -> Dictionary:
	var config_out: Dictionary = {}
	for k: StringName in config:
		config_out[String(k)] = String(config[k])
	var points_out: Dictionary = {}
	for k: StringName in points:
		points_out[String(k)] = points[k]
	var focus_out: Array = []
	for f: int in focus:
		focus_out.append(f)
	var features_out: Array = []
	for f: StringName in features:
		features_out.append(String(f))
	var reviews_out: Array = []
	for r: ReviewResult in review_results:
		reviews_out.append(r.to_dict())
	var units_out: Array = []
	for u: int in weekly_units:
		units_out.append(u)
	return {
		"id": id,
		"company_id": company_id,
		"title": title,
		"config": config_out,
		"phase": Phase.keys()[phase],
		"stage_index": stage_index,
		"stage_progress": stage_progress,
		"focus": focus_out,
		"points": points_out,
		"bugs": bugs,
		"hype": hype,
		"deadline_week": deadline_week,
		"crunch": crunch,
		"delay_weeks_total": delay_weeks_total,
		"contract_id": contract_id,
		"release_week": release_week,
		"units_sold": units_sold,
		"revenue": revenue,
		"user_score": user_score,
		"sentiment": sentiment,
		"kind": Kind.keys()[kind],
		"size_id": String(size_id),
		"engine_id": engine_id,
		"features": features_out,
		"review_results": reviews_out,
		"weekly_units": units_out,
		"promo_until_week": promo_until_week,
		"promo_discount_bp": promo_discount_bp,
		"mod_tools": mod_tools,
		"dlc_count": dlc_count,
	}


static func from_dict(d: Dictionary) -> Project:
	var p := Project.new()
	p.id = int(d["id"])
	p.company_id = int(d["company_id"])
	p.title = String(d["title"])
	var cfg: Dictionary = d["config"]
	for k: StringName in GameState.sorted_names(cfg):
		p.config[k] = StringName(String(cfg[String(k)]))
	p.phase = Phase[String(d["phase"])]
	p.stage_index = int(d["stage_index"])
	p.stage_progress = int(d["stage_progress"])
	p.focus.clear()
	for f: Variant in d["focus"]:
		p.focus.append(int(f))
	var pts: Dictionary = d["points"]
	for k: StringName in GameState.sorted_names(pts):
		p.points[k] = int(pts[String(k)])
	p.bugs = int(d["bugs"])
	p.hype = int(d["hype"])
	p.deadline_week = int(d["deadline_week"])
	p.crunch = bool(d["crunch"])
	p.delay_weeks_total = int(d["delay_weeks_total"])
	p.contract_id = int(d["contract_id"])
	p.release_week = int(d["release_week"])
	p.units_sold = int(d["units_sold"])
	p.revenue = int(d["revenue"])
	p.user_score = int(d["user_score"])
	p.sentiment = int(d["sentiment"])
	p.kind = Kind[String(d["kind"])]
	p.size_id = StringName(String(d["size_id"]))
	p.engine_id = int(d["engine_id"])
	for f: Variant in d["features"]:
		p.features.append(StringName(String(f)))
	for r: Variant in d["review_results"]:
		p.review_results.append(ReviewResult.from_dict(r))
	for u: Variant in d["weekly_units"]:
		p.weekly_units.append(int(u))
	p.promo_until_week = int(d["promo_until_week"])
	p.promo_discount_bp = int(d["promo_discount_bp"])
	p.mod_tools = bool(d["mod_tools"])
	p.dlc_count = int(d["dlc_count"])
	return p
