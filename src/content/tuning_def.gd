class_name TuningDef
extends Resource
## Central tuning numbers (spec 4.1, 6.2). Values live in data/tuning.tres.

@export var seconds_per_week: float = 8.0
@export var max_ticks_per_frame: int = 4
@export var start_money: int = 20000
@export var start_year: int = 1980
@export var weeks_per_year: int = 52
@export var max_staff_default: int = 4
@export var hire_skill_min: int = 10
@export var hire_skill_max: int = 40
@export var crunch_speed_bp: int = 15000
@export var crunch_bug_bp: int = 18000
@export var crunch_burnout_per_week: int = 6
@export var crunch_morale_per_week: int = -4
@export var resign_burnout_threshold: int = 80
@export var resign_base_chance_bp: int = 500
@export var delay_hype_per_week: int = -3


static func load_default() -> TuningDef:
	return load("res://data/tuning.tres") as TuningDef
