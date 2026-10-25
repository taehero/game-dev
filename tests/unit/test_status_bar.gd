extends GutTest

var _saved_locale: String


func before_each() -> void:
	_saved_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	GameRunner.session = GameSession.new(Fixtures.new_state(1), Fixtures.tuning())


func after_each() -> void:
	GameRunner.session = null
	TranslationServer.set_locale("en")


func _bar() -> StatusBar:
	var bar: StatusBar = load("res://src/ui/hud/status_bar.tscn").instantiate()
	add_child_autofree(bar)
	return bar


func _st() -> GameState:
	return GameRunner.session.state


func _refresh(bar: StatusBar) -> void:
	bar.refresh(_st(), GameRunner.session.tuning)


func test_no_project_shows_placeholder() -> void:
	var bar: StatusBar = _bar()
	_refresh(bar)
	assert_eq(bar.get_node("%Title").text, tr("ui.status.no_project"))
	assert_false(bar.get_node("%Stage").visible)


func test_active_project_is_lowest_id_in_production_or_polish() -> void:
	var st: GameState = _st()
	Fixtures.add_project(st, {"phase": Project.Phase.CONCEPT})
	var a: int = Fixtures.add_project(st, {"phase": Project.Phase.PRODUCTION})
	var b: int = Fixtures.add_project(st, {"phase": Project.Phase.POLISH})
	assert_eq(StateQueries.active_project_id(st), a)
	st.projects[a].phase = Project.Phase.RELEASED
	assert_eq(StateQueries.active_project_id(st), b)


func test_other_company_project_is_not_active() -> void:
	var st: GameState = _st()
	Fixtures.add_project(st, {"phase": Project.Phase.PRODUCTION, "company_id": 999})
	assert_eq(StateQueries.active_project_id(st), -1)


func test_project_status_unknown_id_is_empty() -> void:
	assert_eq(StateQueries.project_status(_st(), 12345), {})


func test_shows_title_stage_points_bugs_hype() -> void:
	var st: GameState = _st()
	Fixtures.add_project(st, {
		"title": "Moon Rally", "phase": Project.Phase.PRODUCTION, "stage_index": 1,
		"stage_progress": 4000, "bugs": 5, "hype": 30,
	})
	var pid: int = StateQueries.active_project_id(st)
	var p: Project = st.projects[pid]
	p.points[&"design"] = 12
	p.points[&"tech"] = 7
	p.points[&"art"] = 3
	p.points[&"audio"] = 1
	var bar: StatusBar = _bar()
	_refresh(bar)
	assert_eq(bar.get_node("%Title").text, "Moon Rally")
	assert_eq(bar.get_node("%Stage").text, tr("ui.status.stage").format({"stage": 2, "count": 3, "progress": 40}))
	assert_eq(bar.get_node("%Points").text, tr("ui.status.points").format({"design": 12, "tech": 7, "art": 3, "audio": 1}))
	assert_eq(bar.get_node("%Bugs").text, tr("ui.status.bugs").format({"bugs": 5}))
	assert_eq(bar.get_node("%Hype").text, tr("ui.status.hype").format({"hype": 30}))


func test_refreshes_on_project_changed() -> void:
	var bar: StatusBar = _bar()
	_refresh(bar)
	Fixtures.add_project(_st(), {"title": "Fresh"})
	EventBus.dispatch(&"project_changed", {})
	assert_eq(bar.get_node("%Title").text, "Fresh")


func test_refresh_reads_replaced_session() -> void:
	Fixtures.add_project(_st(), {"title": "Old"})
	var bar: StatusBar = _bar()
	_refresh(bar)
	var fresh: GameState = Fixtures.new_state(2)
	Fixtures.add_project(fresh, {"title": "New"})
	GameRunner.session = GameSession.new(fresh, Fixtures.tuning())
	EventBus.dispatch(&"week_ticked", {})
	assert_eq(bar.get_node("%Title").text, "New")


func test_long_title_is_clipped() -> void:
	Fixtures.add_project(_st(), {"title": "X".repeat(200)})
	var bar: StatusBar = _bar()
	_refresh(bar)
	await get_tree().process_frame
	var title: Label = bar.get_node("%Title")
	assert_true(title.clip_text)
	assert_eq(title.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)
	assert_lte(bar.size.y, 22.0)


func test_speed_buttons_set_speed() -> void:
	var bar: StatusBar = _bar()
	bar.get_node("%Speed2x").pressed.emit()
	assert_eq(GameRunner.session.speed, 2)
	bar.get_node("%Pause").pressed.emit()
	assert_eq(GameRunner.session.speed, 0)


func test_date_and_money_labels() -> void:
	var bar: StatusBar = _bar()
	_refresh(bar)
	var st: GameState = _st()
	assert_eq(bar.get_node("%Date").text, StateQueries.date_text(st, GameRunner.session.tuning))
	assert_eq(bar.get_node("%Money").text, tr("ui.hud.money").format({"money": StateQueries.player_money(st)}))


func test_stage_count_comes_from_game_rules() -> void:
	Fixtures.add_project(_st(), {"kind": Project.Kind.ENGINE, "phase": Project.Phase.PRODUCTION})
	var bar: StatusBar = _bar()
	_refresh(bar)
	assert_string_contains(bar.get_node("%Stage").text, "1/1")


func test_refreshes_on_game_loaded() -> void:
	var bar: StatusBar = _bar()
	var fresh: GameState = Fixtures.new_state(2)
	Fixtures.add_project(fresh, {"title": "Loaded"})
	GameRunner.session = GameSession.new(fresh, Fixtures.tuning())
	EventBus.dispatch(&"game_loaded", {})
	assert_eq(bar.get_node("%Title").text, "Loaded")
