class_name Project
extends RefCounted

enum Phase { CONCEPT, PRODUCTION, POLISH, RELEASED, LIVE, RETIRED }

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
}

var id: int
var company_id: int
var title: String
var config: Dictionary[StringName, StringName] = {}  # platform, engine, genre, topic, art_style, business_model
var phase: Phase = Phase.CONCEPT
var stage_index: int = 0
var stage_progress: int = 0  # 0-100
var focus: Array[int] = [50, 50, 50]  # tech share per stage
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
	return p
