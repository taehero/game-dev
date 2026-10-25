extends GutTest


func test_combo_label() -> void:
	var s := Fixtures.new_state(1)
	var t := Fixtures.tuning()
	assert_eq(StateQueries.combo_label_key(s, 1, &"topic_fx_space", &"genre_fx_action", t), &"ui.combo.unknown")
	Fixtures.add_project(s, {"phase": Project.Phase.LIVE, "user_score": 66})
	assert_eq(StateQueries.combo_label_key(s, 1, &"topic_fx_space", &"genre_fx_action", t), &"ui.combo.good")
	Fixtures.add_project(s, {"phase": Project.Phase.RETIRED, "user_score": 85})
	assert_eq(StateQueries.combo_label_key(s, 1, &"topic_fx_space", &"genre_fx_action", t), &"ui.combo.great")
	assert_eq(StateQueries.combo_label_key(s, 1, &"topic_fx_ghost", &"genre_fx_action", t), &"ui.combo.unknown")


func test_project_status_includes_stage_count() -> void:
	var s := Fixtures.new_state(1)
	var pid := Fixtures.add_project(s)
	assert_eq(StateQueries.project_status(s, pid)["stage_count"], 3)
	var eid := Fixtures.add_project(s, {"kind": Project.Kind.ENGINE})
	assert_eq(StateQueries.project_status(s, eid)["stage_count"], 1)
