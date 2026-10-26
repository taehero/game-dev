extends GutTest

const HOST_SCENE: PackedScene = preload("res://src/ui/panels/panel_host.tscn")

var _host: PanelHost
var _panel: ProjectPanel


func before_each() -> void:
	TranslationServer.set_locale("en")
	GameRunner.session = GameSession.new(Fixtures.new_state(1), Fixtures.tuning())
	GameRunner.session.set_speed(0)


func after_each() -> void:
	GameRunner.session = null
	TranslationServer.set_locale("en")


func _view() -> GameState:
	return GameRunner.session.state


func _mount() -> ProjectPanel:
	_host = HOST_SCENE.instantiate()
	add_child_autofree(_host)
	_panel = ProjectPanel.new()
	_host.set_panel(&"project", _panel)
	_host.show_tab(&"project")
	return _panel


func _project(pid: int) -> Project:
	return _view().projects[pid]


func _node(path: String) -> Node:
	return _panel.get_node_or_null(path)


func test_no_project_shows_new_buttons_and_signals() -> void:
	_mount()
	assert_not_null(_node("%None"))
	assert_eq((_node("%None") as Label).text, tr("ui.project.none"))
	assert_null(_node("%Release"))
	watch_signals(_panel)
	(_node("%NewGame") as Button).pressed.emit()
	(_node("%NewEngine") as Button).pressed.emit()
	assert_signal_emitted(_panel, "new_game_requested")
	assert_signal_emitted(_panel, "new_engine_requested")


func test_active_game_shows_three_stage_sliders() -> void:
	var pid: int = Fixtures.add_project(_view())
	_mount()
	assert_null(_node("%None"))
	assert_eq((_node("%Title") as Label).text, _project(pid).title)
	assert_string_contains((_node("%Phase") as Label).text, tr("ui.phase.production"))
	for s: int in 3:
		var triple: SliderTriple = _node("%%Stage_%d" % s) as SliderTriple
		assert_not_null(triple, "Stage_%d" % s)
		assert_eq(triple.values(), _project(pid).focus.slice(s * 3, s * 3 + 3))
	assert_not_null(_node("%Focus"))
	assert_false((_node("%Release") as Button).visible)


func test_past_stage_sliders_disabled() -> void:
	Fixtures.add_project(_view(), {"stage_index": 1})
	_mount()
	var past: HSlider = _node("%Stage_0").get_node("Row_0/Slider") as HSlider
	var current: HSlider = _node("%Stage_1").get_node("Row_0/Slider") as HSlider
	assert_false(past.editable)
	assert_eq((_node("%Stage_0") as SliderTriple).modulate.a, 0.5)
	assert_ne(past.tooltip_text, "")
	assert_eq((_node("%Stage_1") as SliderTriple).modulate.a, 1.0)
	assert_eq(current.tooltip_text, "")
	assert_true(current.editable)


func test_slider_change_submits_set_sliders() -> void:
	var pid: int = Fixtures.add_project(_view())
	_mount()
	(_node("%Stage_0") as SliderTriple).set_share(0, 6000)
	assert_eq(_project(pid).focus.slice(0, 3), [6000, 2000, 2000] as Array[int])
	assert_eq(_panel.status_label().text, "")


func test_refused_slider_resyncs_from_state() -> void:
	var pid: int = Fixtures.add_project(_view())
	_mount()
	_project(pid).phase = Project.Phase.POLISH
	(_node("%Stage_0") as SliderTriple).set_share(0, 6000)
	assert_ne(_panel.status_label().text, "")
	var triple: SliderTriple = _node("%Stage_0") as SliderTriple
	assert_eq(triple.values(), _project(pid).focus.slice(0, 3))
	assert_eq(_project(pid).focus.slice(0, 3), Project.DEFAULT_FOCUS.slice(0, 3))


func test_release_in_polish() -> void:
	var pid: int = Fixtures.add_project(_view(), {"phase": Project.Phase.POLISH})
	_mount()
	var release: Button = _node("%Release") as Button
	assert_true(release.visible)
	assert_false(release.disabled)
	release.pressed.emit()
	assert_eq(_project(pid).phase, Project.Phase.RELEASED)
	assert_eq(_project(pid).review_results.size(), 4)


func test_bug_hunt_button_emits_request() -> void:
	var pid: int = Fixtures.add_project(_view(), {"phase": Project.Phase.POLISH, "bugs": 5})
	_mount()
	var hunt: Button = _node("%BugHunt") as Button
	assert_true(hunt.visible)
	watch_signals(_panel)
	hunt.pressed.emit()
	assert_signal_emitted_with_parameters(_panel, "bug_hunt_requested", [pid])


func test_bug_hunt_hidden_without_bugs() -> void:
	Fixtures.add_project(_view(), {"phase": Project.Phase.POLISH, "bugs": 0})
	_mount()
	assert_false((_node("%BugHunt") as Button).visible)


func test_engine_project_has_no_sliders() -> void:
	Fixtures.add_project(_view(), {"kind": Project.Kind.ENGINE})
	_mount()
	assert_null(_node("%Stage_0"))
	assert_null(_node("%Focus"))
	assert_not_null(_node("%EngineBuilding"))
	assert_eq((_node("%EngineBuilding") as Label).text, tr("ui.project.engine_building"))


func test_past_games_rows_and_details_signal() -> void:
	var a: int = Fixtures.add_project(_view(), {"phase": Project.Phase.LIVE, "release_week": 3,
		"user_score": 75, "units_sold": 120, "revenue": 4500})
	var b: int = Fixtures.add_project(_view(), {"phase": Project.Phase.RELEASED, "release_week": 9,
		"user_score": 60, "units_sold": 5, "revenue": 90})
	_mount()
	assert_null(_node("%NoPastGames"))
	var rows: Node = _node("%PastGames")
	assert_not_null(rows.find_child("Game_%d" % a, true, false))
	var row_b: Node = rows.find_child("Game_%d" % b, true, false)
	assert_not_null(row_b)
	var texts: PackedStringArray = []
	for l: Label in UiFit.labels_under(row_b):
		texts.append(l.text)
	var joined: String = " ".join(texts)
	assert_string_contains(joined, UiFormat.score(60))
	assert_string_contains(joined, UiFormat.money(90))
	assert_string_contains(joined, tr("ui.phase.released"))
	watch_signals(_panel)
	(row_b.find_child("Details", true, false) as Button).pressed.emit()
	assert_signal_emitted_with_parameters(_panel, "details_requested", [b])


func test_no_past_games_message() -> void:
	_mount()
	assert_not_null(_node("%NoPastGames"))


func test_project_panel_fits_th() -> void:
	TranslationServer.set_locale("th")
	Fixtures.add_project(_view(), {"title": "เกมผจญภัยอวกาศสุดมหัศจรรย์"})
	Fixtures.add_project(_view(), {"title": "เกมแข่งรถ", "phase": Project.Phase.LIVE, "release_week": 3,
		"user_score": 88, "units_sold": 1234567, "revenue": 1234567})
	Fixtures.add_project(_view(), {"title": "เกมปริศนาแสนสนุก", "phase": Project.Phase.RELEASED,
		"release_week": 5, "user_score": 71, "units_sold": 9999999, "revenue": 9876543})
	_mount()
	await wait_process_frames(2)
	var content: Control = _host.get_node("%Content") as Control
	assert_true(content.get_global_rect().encloses(_panel.get_global_rect()))
	for label: Label in UiFit.labels_under(_panel):
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF or label.clip_text:
			continue
		assert_true(UiFit.text_fits(label), "label '%s' clipped" % label.text)
