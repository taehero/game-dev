extends GutTest


func after_each() -> void:
	GameRunner.session = null


func _main() -> Control:
	return add_child_autofree(load("res://src/ui/main.tscn").instantiate())


func test_main_has_bars_and_hidden_debug_hud() -> void:
	var m := _main()
	assert_not_null(m.get_node("StatusBar"))
	assert_not_null(m.get_node("TabBarShell"))
	assert_not_null(m.get_node("OfficeSlot"))
	assert_false(m.get_node("DebugLayer/DebugHud").visible)


func test_f3_toggles_debug_hud() -> void:
	var m := _main()
	var ev := InputEventKey.new()
	ev.keycode = KEY_F3
	ev.pressed = true
	m._unhandled_input(ev)
	assert_true(m.get_node("DebugLayer/DebugHud").visible)
	m._unhandled_input(ev)
	assert_false(m.get_node("DebugLayer/DebugHud").visible)


func test_office_origin_centres_rooms() -> void:
	var main_script: GDScript = load("res://src/ui/main.gd")
	assert_eq(main_script.office_origin(Vector2i(192, 128)), Vector2i(128, 30))
	assert_eq(main_script.office_origin(Vector2i(288, 144)), Vector2i(32, 14))


func test_tab_opens_panel_host() -> void:
	var m := _main()
	m.get_node("TabBarShell/Tab_market").button_pressed = true
	assert_eq((m.get_node("PanelHost") as PanelHost).current_tab(), &"market")


func test_project_theme_is_main_theme() -> void:
	assert_eq(String(ProjectSettings.get_setting("gui/theme/custom")), "res://src/ui/theme/main_theme.tres")


func test_status_bar_filled_at_launch() -> void:
	var m := _main()
	var st: GameState = GameRunner.session.state
	assert_eq(m.get_node("StatusBar").get_node("%Date").text,
		StateQueries.date_text(st, GameRunner.session.tuning))
