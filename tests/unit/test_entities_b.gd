extends GutTest


func _sample_project() -> Project:
	var p := Project.new()
	p.id = 5
	p.company_id = 1
	p.title = "Dragon Quest Clone"
	p.config = {
		&"platform": &"platform_pc",
		&"engine": &"engine_basic",
		&"genre": &"genre_rpg",
		&"topic": &"topic_fantasy",
		&"art_style": &"art_pixel",
		&"business_model": &"biz_premium",
	}
	p.phase = Project.Phase.PRODUCTION
	p.stage_index = 1
	p.stage_progress = 42
	p.focus = [30, 60, 90]
	p.points = {&"design": 10, &"tech": 20, &"art": 30, &"audio": 4}
	p.bugs = 3
	p.hype = 15
	p.deadline_week = 200
	p.crunch = true
	p.delay_weeks_total = 2
	p.contract_id = 9
	p.release_week = 210
	p.units_sold = 1000
	p.revenue = 55000
	p.user_score = 77
	p.sentiment = -4
	return p


func _sample_market() -> Market:
	var m := Market.new()
	m.segment_size = {&"genre_rpg": 5000, &"genre_action": 8000}
	m.segment_growth_bp = {&"genre_rpg": 250, &"genre_action": -100}
	m.taste_bp = {&"genre_rpg": 11001, &"genre_action": 9000}
	m.platform_install_base = {&"platform_pc": 100000}
	m.focus_drift = {&"genre_rpg": [-3, 0, 7]}
	return m


func _sample_event() -> ActiveWorldEvent:
	var e := ActiveWorldEvent.new()
	e.event_id = &"event_crash"
	e.start_week = 10
	e.end_week = 20
	return e


func _sample_post() -> ForumPost:
	var f := ForumPost.new()
	f.id = 3
	f.project_id = 5
	f.week = 211
	f.topic_key = &"topic_bugs"
	f.sentiment = -20
	f.replied = true
	return f


func _sample_decision() -> Decision:
	var d := Decision.new()
	d.id = 8
	d.kind = &"publisher_offer"
	d.related_ids = [4, 9]
	d.deadline_week = 150
	d.option_keys = [&"accept", &"decline"]
	return d


func _json(d: Dictionary) -> String:
	return JSON.stringify(d, "", true, true)


func test_project_survives_json_round_trip() -> void:
	var p := _sample_project()
	var back: Project = Project.from_dict(Fixtures.json_round_trip(p.to_dict()))
	assert_eq(_json(back.to_dict()), _json(p.to_dict()))
	assert_eq(typeof(back.id), TYPE_INT)
	assert_eq(typeof(back.config[&"genre"]), TYPE_STRING_NAME)
	assert_eq(typeof(back.config.keys()[0]), TYPE_STRING_NAME)
	assert_eq(typeof(back.points.keys()[0]), TYPE_STRING_NAME)
	assert_eq(typeof(back.focus[2]), TYPE_INT)
	assert_eq(back.focus, [30, 60, 90] as Array[int])
	assert_eq(back.phase, Project.Phase.PRODUCTION)
	assert_true(back.crunch)
	assert_eq(back.contract_id, 9)


func test_project_schema_accepts_round_tripped_dict() -> void:
	assert_true(SaveSchema.check(Fixtures.json_round_trip(_sample_project().to_dict()), Project.SCHEMA))


func test_project_enum_serializes_as_name() -> void:
	assert_eq(_sample_project().to_dict()["phase"], "PRODUCTION")


func test_market_survives_json_round_trip() -> void:
	var m := _sample_market()
	var back: Market = Market.from_dict(Fixtures.json_round_trip(m.to_dict()))
	assert_eq(_json(back.to_dict()), _json(m.to_dict()))
	assert_eq(typeof(back.segment_size.keys()[0]), TYPE_STRING_NAME)
	assert_eq(typeof(back.segment_size[&"genre_rpg"]), TYPE_INT)
	assert_eq(back.segment_growth_bp[&"genre_action"], -100)
	assert_eq(back.platform_install_base[&"platform_pc"], 100000)


func test_market_schema_accepts_round_tripped_dict() -> void:
	assert_true(SaveSchema.check(Fixtures.json_round_trip(_sample_market().to_dict()), Market.SCHEMA))


func test_market_taste_bp_survives_exactly_as_int() -> void:
	var m := Market.new()
	m.taste_bp[&"genre_rpg"] = 11001
	var back: Market = Market.from_dict(Fixtures.json_round_trip(m.to_dict()))
	assert_eq(typeof(back.taste_bp[&"genre_rpg"]), TYPE_INT)
	assert_eq(back.taste_bp[&"genre_rpg"], 11001)


func test_market_focus_drift_values_are_ints() -> void:
	var m := Market.new()
	m.focus_drift[&"genre_rpg"] = [-3, 0, 7]
	var back: Market = Market.from_dict(Fixtures.json_round_trip(m.to_dict()))
	assert_eq(typeof(back.focus_drift[&"genre_rpg"][2]), TYPE_INT)
	assert_eq(back.focus_drift[&"genre_rpg"], [-3, 0, 7])


func test_active_world_event_survives_json_round_trip() -> void:
	var e := _sample_event()
	var back: ActiveWorldEvent = ActiveWorldEvent.from_dict(Fixtures.json_round_trip(e.to_dict()))
	assert_eq(_json(back.to_dict()), _json(e.to_dict()))
	assert_eq(typeof(back.event_id), TYPE_STRING_NAME)
	assert_eq(typeof(back.end_week), TYPE_INT)


func test_active_world_event_schema_accepts_round_tripped_dict() -> void:
	assert_true(SaveSchema.check(Fixtures.json_round_trip(_sample_event().to_dict()), ActiveWorldEvent.SCHEMA))


func test_forum_post_survives_json_round_trip() -> void:
	var f := _sample_post()
	var back: ForumPost = ForumPost.from_dict(Fixtures.json_round_trip(f.to_dict()))
	assert_eq(_json(back.to_dict()), _json(f.to_dict()))
	assert_eq(typeof(back.topic_key), TYPE_STRING_NAME)
	assert_eq(typeof(back.id), TYPE_INT)
	assert_true(back.replied)


func test_forum_post_schema_accepts_round_tripped_dict() -> void:
	assert_true(SaveSchema.check(Fixtures.json_round_trip(_sample_post().to_dict()), ForumPost.SCHEMA))


func test_decision_survives_json_round_trip() -> void:
	var d := _sample_decision()
	var back: Decision = Decision.from_dict(Fixtures.json_round_trip(d.to_dict()))
	assert_eq(_json(back.to_dict()), _json(d.to_dict()))
	assert_eq(typeof(back.kind), TYPE_STRING_NAME)
	assert_eq(typeof(back.related_ids[1]), TYPE_INT)
	assert_eq(typeof(back.option_keys[0]), TYPE_STRING_NAME)
	assert_eq(back.related_ids, [4, 9] as Array[int])


func test_decision_schema_accepts_round_tripped_dict() -> void:
	assert_true(SaveSchema.check(Fixtures.json_round_trip(_sample_decision().to_dict()), Decision.SCHEMA))
