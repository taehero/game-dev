extends GutTest

var s: GameState
var t: TuningDef


func before_each() -> void:
	s = Fixtures.new_state(1)
	t = Fixtures.tuning()


func _game(overrides: Dictionary = {}) -> StartProjectCommand:
	var a: Dictionary = {"title": "Star Run", "size": &"size_small", "platform": &"platform_fx_micro", "topic": &"topic_fx_space",
		"genre": &"genre_fx_action", "engine_id": -1, "lic": &"lic_engine_homebrew", "features": [] as Array[StringName]}
	a.merge(overrides, true)
	return StartProjectCommand.game(1, a["title"], a["size"], a["platform"], a["topic"], a["genre"], a["engine_id"], a["lic"], a["features"])


func test_start_game_assigns_free_workers() -> void:
	var w: int = Fixtures.add_worker(s)
	var cmd: StartProjectCommand = _game()
	assert_true(cmd.validate(s, t).ok)
	cmd.apply(TickContext.new(s, t))
	var p: Project = s.projects[s.next_id - 1]
	assert_eq(p.phase, Project.Phase.PRODUCTION)
	assert_eq(p.config[&"engine"], &"lic_engine_homebrew")
	assert_eq(p.deadline_week, 18)
	assert_eq(p.focus, Project.DEFAULT_FOCUS)
	assert_eq(s.staff[w].assigned_project_id, p.id)
	assert_eq(s.staff[s.owner_staff_id()].assigned_project_id, p.id)


func test_second_project_has_no_free_staff() -> void:
	_game().apply(TickContext.new(s, t))
	assert_eq(_game().validate(s, t).reason_key, &"error.not_enough_staff")


func test_rejection_reasons() -> void:
	assert_eq(_game({"title": "  "}).validate(s, t).reason_key, &"error.title_empty")
	assert_eq(_game({"size": &"size_medium"}).validate(s, t).reason_key, &"error.item_locked")
	assert_eq(_game({"platform": &"platform_fx_console"}).validate(s, t).reason_key, &"error.platform_not_on_sale")
	assert_eq(_game({"genre": &"genre_fx_adventure"}).validate(s, t).reason_key, &"error.item_locked")
	assert_eq(_game({"lic": &"lic_engine_fx_pro"}).validate(s, t).reason_key, &"error.engine_unavailable")
	assert_eq(_game({"features": [&"feature_fx_scroll"] as Array[StringName]}).validate(s, t).reason_key, &"error.item_locked")
	s.week = 20
	assert_eq(_game({"platform": &"platform_fx_console"}).validate(s, t).reason_key, &"error.no_dev_kit")


func test_not_found_reasons() -> void:
	assert_eq(_game({"size": &"nope"}).validate(s, t).reason_key, &"error.size_not_found")
	assert_eq(_game({"platform": &"nope"}).validate(s, t).reason_key, &"error.platform_not_found")
	assert_eq(_game({"topic": &"nope"}).validate(s, t).reason_key, &"error.topic_not_found")
	assert_eq(_game({"genre": &"nope"}).validate(s, t).reason_key, &"error.genre_not_found")
	assert_eq(_game({"features": [&"nope"] as Array[StringName]}).validate(s, t).reason_key, &"error.feature_not_found")


func test_feature_not_in_engine() -> void:
	s.companies[1].unlocked = [&"research_fx_scroll"]
	assert_eq(_game({"features": [&"feature_fx_scroll"] as Array[StringName]}).validate(s, t).reason_key, &"error.feature_not_in_engine")


func test_retired_platform_refused() -> void:
	s.week = 400
	assert_eq(_game().validate(s, t).reason_key, &"error.platform_not_on_sale")


func test_built_engine_features_allowed() -> void:
	var eid: int = Fixtures.add_engine(s, {"features": [&"feature_fx_save"] as Array[StringName]})
	var cmd: StartProjectCommand = _game({"engine_id": eid, "lic": &"", "features": [&"feature_fx_save"] as Array[StringName]})
	assert_true(cmd.validate(s, t).ok)
	cmd.apply(TickContext.new(s, t))
	var p: Project = s.projects[s.next_id - 1]
	assert_eq(p.engine_id, eid)
	assert_eq(p.config[&"engine"], &"")


func test_engine_project() -> void:
	s.companies[1].unlocked = [&"research_fx_scroll"]
	var cmd: StartProjectCommand = StartProjectCommand.engine(1, "Engine 1", [&"feature_fx_scroll", &"feature_fx_save"] as Array[StringName])
	assert_true(cmd.validate(s, t).ok)
	cmd.apply(TickContext.new(s, t))
	var p: Project = s.projects[s.next_id - 1]
	assert_eq(p.kind, Project.Kind.ENGINE)
	assert_eq(p.focus, GameRules.ENGINE_FOCUS)
	assert_eq(p.deadline_week, 6)
	assert_eq(StartProjectCommand.engine(1, "E", [] as Array[StringName]).validate(s, t).reason_key, &"error.no_features")
