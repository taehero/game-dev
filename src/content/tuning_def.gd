class_name TuningDef
extends Resource
## Central tuning numbers (spec 4.1, 6.2). Values live in data/tuning.tres.

@export var seconds_per_week: float = 8.0
@export var max_ticks_per_frame: int = 4
@export var start_money: int = 20000
@export var start_year: int = 1980
@export var weeks_per_year: int = 52
@export var hire_skill_min: int = 10
@export var hire_skill_max: int = 40
@export var crunch_speed_bp: int = 15000
@export var crunch_bug_bp: int = 18000
@export var crunch_burnout_per_week: int = 6
@export var crunch_morale_per_week: int = -4
@export var resign_burnout_threshold: int = 80
@export var resign_base_chance_bp: int = 500
@export var delay_hype_per_week: int = -3

@export var start_office_id: StringName = &"office_garage"
@export var start_equipment_def: StringName = &"equipment_micro_1980"
@export var start_equipment_value: int = 800
@export var owner_start_skill: int = 30
@export var points_per_skill: int = 10
@export var morale_factor_min_bp: int = 6000
@export var morale_factor_max_bp: int = 12000
@export var bugs_per_staff_week_bp: int = 20000
@export var engine_age_bug_bp_per_year: int = 500
@export var polish_bugs_fixed_per_staff_week: int = 3
@export var engine_base_tech_cap: int = 30
@export var engine_min_staff: int = 1
@export var research_per_point_bp: int = 1000
@export var review_par_score_x10: int = 60
@export var review_innovation_base_x10: int = 40
@export var review_innovation_per_feature_x10: int = 8
@export var review_innovation_new_combo_x10: int = 20
@export var review_bug_density_divisor: int = 5
@export var review_noise_x10: int = 3
@export var combo_great_x10: int = 80
@export var combo_good_x10: int = 65
@export var combo_okay_x10: int = 50
@export var sales_hype_table_bp: Array[int] = [10000, 11000, 12000, 13000, 14000, 15000, 16000, 17000, 18000, 19000, 20000]
@export var sales_review_table_bp: Array[int] = [1000, 1000, 2000, 3500, 5500, 8000, 10000, 13000, 17000, 22000, 28000]
@export var sales_decay_table_bp: Array[int] = [5000, 5000, 6000, 7000, 7600, 8200, 8600, 8900, 9100, 9300, 9400]
@export var sales_floor_units: int = 10


static func load_default() -> TuningDef:
	return load("res://data/tuning.tres") as TuningDef
