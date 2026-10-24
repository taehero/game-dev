extends GutTest


func test_default_tuning_matches_spec() -> void:
	var t: TuningDef = TuningDef.load_default()
	assert_eq(t.seconds_per_week, 8.0)
	assert_eq(t.max_ticks_per_frame, 4)
	assert_eq(t.crunch_speed_bp, 15000)
	assert_eq(t.crunch_bug_bp, 18000)
	assert_eq(t.crunch_burnout_per_week, 6)
	assert_eq(t.crunch_morale_per_week, -4)
	assert_eq(t.resign_burnout_threshold, 80)
	assert_eq(t.resign_base_chance_bp, 500)
	assert_eq(t.delay_hype_per_week, -3)
