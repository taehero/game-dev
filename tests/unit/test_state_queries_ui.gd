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
