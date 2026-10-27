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

## --- M2d panels ---
@export var production_event_chance_bp: int = 1200
@export var production_event_max_per_project: int = 2
@export var production_event_answer_weeks: int = 4
@export var bug_hunt_max_bugs: int = 10
@export var bug_hunt_seconds: float = 15.0
@export var hire_offer_salary: int = 1700

## --- M2b people and money ---
@export var era_wage_base: int = 500
@export var wage_per_skill_point: int = 17
@export var raise_threshold_bp: int = 9000
@export var raise_answer_weeks: int = 4
@export var raise_refuse_morale: int = -15
@export var promotion_refuse_morale: int = -10
@export var promotion_ask_cooldown_weeks: int = 26
@export var severance_months: int = 1
@export var fire_morale_penalty: int = -5
@export var staff_exp_per_point_bp: int = 1000
@export var burnout_recovery_per_week: int = 2
@export var morale_baseline: int = 70
@export var morale_recovery_per_week: int = 1
@export var resign_morale_threshold: int = 15
@export var resign_chance_per_burnout_bp: int = 100
@export var resign_refusals_double: int = 2
@export var lead_chemistry_bp: int = 500
@export var candidates_per_month: int = 3
@export var candidate_expiry_weeks: int = 8
@export var candidate_name_count: int = 24
@export var candidate_salary_noise_min_pct: int = -10
@export var candidate_salary_noise_max_pct: int = 15
@export var owner_xp_per_point: int = 3000
@export var owner_xp_per_release: int = 1500
@export var owner_solo_limit: int = 3
@export var owner_neglect_focus_bp: int = 7000
@export var owner_neglect_morale: int = -5
@export var depreciation_bp_per_month: int = 200
@export var outdated_speed_bp: int = 8000
@export var outdated_bug_bp: int = 13000
@export var contract_offers_per_month: int = 2
@export var contract_offer_weeks: int = 4
@export var contract_points_min: int = 150
@export var contract_points_max: int = 500
@export var contract_weeks_min: int = 6
@export var contract_weeks_max: int = 12
@export var contract_pay_per_point: int = 1
@export var contract_miss_pay_bp: int = 5000
@export var contract_miss_reputation: int = -3
@export var outsource_engine_base_price: int = 2000
@export var outsource_price_per_feature_week: int = 500
@export var outsource_late_roll_below: int = 30
@export var outsource_max_late_weeks: int = 4
@export var outsource_low_quality_roll: int = 40
@export var outsource_low_quality_cap_penalty: int = 10
@export var outsource_part_price: int = 1500
@export var outsource_part_par_bp: int = 2500
@export var bank_limit_base: int = 10000
@export var bank_limit_per_rep: int = 500
@export var bank_rate_bp_per_month: int = 100
@export var bank_refuse_weeks: int = 52
@export var shark_limit: int = 15000
@export var shark_rate_bp_per_month: int = 800
@export var loan_term_months: int = 24
@export var shark_repossess_bp: int = 15000
@export var shark_seize_bp: int = 2000
@export var shark_seize_after_missed: int = 3
@export var repossess_reputation: int = -5
@export var repossess_morale: int = -10
@export var bankrupt_months: int = 3
@export var candidate_level_weights: Array[int] = [60, 30, 10, 0]
@export var candidate_level_skill_bonus: Array[int] = [0, 15, 30, 45]

## --- M2c after launch ---
@export var hype_decay_bp: int = 9500
@export var promo_discount_step_bp: int = 1000
@export var promo_max_weeks: int = 4
@export var promo_uplift_table_bp: Array[int] = [13000, 16000, 19000, 22000, 25000]
@export var promo_fatigue_window_weeks: int = 26
@export var promo_fatigue_hype: int = 5
@export var promo_fatigue_recovery_per_month: int = 1
@export var patch_staff_weeks: int = 4
@export var patch_bugs_per_staff_week: int = 5
@export var patch_user_score_x10: int = 3
@export var patch_sentiment: int = 5
@export var mod_tools_staff_weeks: int = 8
@export var mod_tail_bp: int = 300
@export var mod_dlc_penalty_bp: int = 2000
@export var mod_viral_chance_bp: int = 500
@export var mod_viral_fans: int = 2000
@export var mod_viral_units_bp: int = 10000
@export var mod_viral_sentiment: int = 10
@export var dlc_size_id: StringName = &"size_dlc"
@export var dlc_tail_uplift_bp: int = 5000
@export var forum_post_base_chance_bp: int = 500
@export var forum_post_chance_per_bug_bp: int = 50
@export var forum_post_max_chance_bp: int = 3000
@export var forum_post_sentiment: int = -5
@export var forum_apologise_sentiment: int = 3
@export var forum_promise_sentiment: int = 8
@export var forum_posts_cap: int = 40
@export var sentiment_decay_bp_per_point: int = 5
@export var sales_decay_max_bp: int = 9800
@export var award_window_weeks: int = 52
@export var award_bonus_max_x10: int = 8
@export var award_ai_entries: int = 3
@export var award_ai_score_min_x10: int = 50
@export var award_ai_score_max_x10: int = 85
@export var award_reputation: int = 5


static func load_default() -> TuningDef:
	return load("res://data/tuning.tres") as TuningDef
