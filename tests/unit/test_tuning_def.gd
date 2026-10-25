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
	assert_eq(t.points_per_skill, 10)
	assert_eq(t.research_per_point_bp, 1000)
	assert_eq(t.review_noise_x10, 3)
	assert_eq(t.sales_floor_units, 10)
	assert_eq(t.sales_decay_table_bp.size(), 11)
	assert_eq(t.sales_review_table_bp.size(), 11)
	assert_eq(t.sales_hype_table_bp.size(), 11)


func test_shipped_tuning_matches_script_defaults() -> void:
	var shipped: TuningDef = TuningDef.load_default()
	var defaults := TuningDef.new()
	for prop: Dictionary in defaults.get_property_list():
		if not (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n: String = String(prop["name"])
		assert_eq(shipped.get(n), defaults.get(n), "tuning field %s" % n)
