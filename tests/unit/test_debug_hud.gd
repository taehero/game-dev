extends GutTest

var _saved_dir: String
var _saved_locale: String
var _dir: String = ""

func before_each() -> void:
	_saved_dir = GameRunner.save_dir
	_dir = "user://test_hud_saves_%d" % Time.get_ticks_usec()
	GameRunner.save_dir = _dir
	_saved_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")

func after_each() -> void:
	GameRunner.save_dir = _saved_dir
	GameRunner.session = null
	TranslationServer.set_locale(_saved_locale)
	var abs_dir: String = ProjectSettings.globalize_path(_dir)
	if DirAccess.dir_exists_absolute(abs_dir):
		for f: String in DirAccess.get_files_at(abs_dir):
			DirAccess.remove_absolute(abs_dir.path_join(f))
		DirAccess.remove_absolute(abs_dir)

func _make_hud() -> Control:
	return add_child_autofree(load("res://src/ui/debug_hud.tscn").instantiate())

func test_speed_button_sets_game_speed() -> void:
	GameRunner.start_new_game(1, "T")
	var hud: Control = _make_hud()
	hud.get_node("%Speed1x").pressed.emit()
	assert_eq(GameRunner.session.speed, 1)
	hud.get_node("%Pause").pressed.emit()
	assert_eq(GameRunner.session.speed, 0)

func test_hire_button_adds_staff_and_updates_label() -> void:
	GameRunner.start_new_game(1, "T")
	var hud: Control = _make_hud()
	var st: GameState = GameRunner.session.state
	var before: int = StateQueries.staff_count(st, st.player_company_id)
	hud.get_node("%Hire").pressed.emit()
	assert_eq(StateQueries.staff_count(st, st.player_company_id), before + 1)
	EventBus.dispatch(&"staff_hired", {})
	assert_string_contains(hud.get_node("%StaffLabel").text, str(before + 1))

func test_state_queries_date_text() -> void:
	GameRunner.start_new_game(1, "T")
	var st: GameState = GameRunner.session.state
	var t: TuningDef = GameRunner.session.tuning
	assert_eq(StateQueries.date_text(st, t), "Year %d, Week 1" % t.start_year)

func test_rejected_command_shows_translated_reason() -> void:
	GameRunner.start_new_game(1, "T")
	var hud: Control = _make_hud()
	EventBus.dispatch(&"command_rejected", {"reason_key": &"error.staff_limit"})
	assert_eq(hud.get_node("%MessageLabel").text, tr("error.staff_limit"))

func test_load_missing_slot_shows_error() -> void:
	GameRunner.start_new_game(1, "T")
	var hud: Control = _make_hud()
	hud.get_node("%Load").pressed.emit()
	assert_ne(hud.get_node("%MessageLabel").text, "")

func test_speed_button_text_is_translated() -> void:
	GameRunner.start_new_game(1, "T")
	var hud: Control = _make_hud()
	assert_eq(hud.get_node("%Speed2x").text, tr("ui.hud.speed").format({"speed": 2}))

func test_main_scene_fills_labels_at_launch() -> void:
	var main: Control = add_child_autofree(load("res://src/ui/main.tscn").instantiate())
	var label: Label = main.get_node("DebugHud/Box/DateLabel")
	var st: GameState = GameRunner.session.state
	assert_ne(label.text, "")
	assert_eq(label.text, StateQueries.date_text(st, GameRunner.session.tuning))

func test_state_queries_player_company_id() -> void:
	GameRunner.start_new_game(1, "T")
	var st: GameState = GameRunner.session.state
	assert_eq(StateQueries.player_company_id(st), st.player_company_id)
	assert_gt(StateQueries.player_company_id(st), 0)
