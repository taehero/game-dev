extends GutTest


func test_active_project_is_lowest_id_in_production_or_polish() -> void:
	var st: GameState = Fixtures.new_state(1)
	Fixtures.add_project(st, {"phase": Project.Phase.CONCEPT})
	var a: int = Fixtures.add_project(st, {"phase": Project.Phase.PRODUCTION})
	var b: int = Fixtures.add_project(st, {"phase": Project.Phase.POLISH})
	assert_eq(StateQueries.active_project_id(st), a)
	st.projects[a].phase = Project.Phase.RELEASED
	assert_eq(StateQueries.active_project_id(st), b)


func test_other_company_project_is_not_active() -> void:
	var st: GameState = Fixtures.new_state(1)
	Fixtures.add_project(st, {"phase": Project.Phase.PRODUCTION, "company_id": 999})
	assert_eq(StateQueries.active_project_id(st), -1)


func test_project_status_unknown_id_is_empty() -> void:
	assert_eq(StateQueries.project_status(Fixtures.new_state(1), 12345), {})


func test_project_status_has_topic_and_genre() -> void:
	var st: GameState = Fixtures.new_state(1)
	var pid: int = Fixtures.add_project(st)
	var info: Dictionary = StateQueries.project_status(st, pid)
	assert_eq(info["topic_id"], &"topic_fx_space")
	assert_eq(info["genre_id"], &"genre_fx_action")


func test_resource_view_fields() -> void:
	var st: GameState = Fixtures.new_state(1)
	var t: TuningDef = Fixtures.tuning()
	st.companies[st.player_company_id].money = 5000
	st.companies[st.player_company_id].fan_count = 1240
	var pid: int = Fixtures.add_project(st, {"phase": Project.Phase.PRODUCTION})
	st.projects[pid].hype = 35
	assert_eq(StateQueries.resource_view(st, t), {
		"date_text": StateQueries.date_text(st, t), "money": 5000, "fans": 1240, "hype": 35,
	})


func test_resource_view_hype_zero_without_project() -> void:
	var st: GameState = Fixtures.new_state(1)
	assert_eq(StateQueries.resource_view(st, Fixtures.tuning())["hype"], 0)


func test_resource_view_without_company() -> void:
	var st: GameState = Fixtures.new_state(1)
	st.player_company_id = 999
	var view: Dictionary = StateQueries.resource_view(st, Fixtures.tuning())
	assert_eq(view["money"], 0)
	assert_eq(view["fans"], 0)
