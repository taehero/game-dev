extends GutTest


func before_all() -> void:
	Fixtures.use_real_content()


func after_all() -> void:
	ContentDB.use(Fixtures.content())


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


func test_office_mounted_and_centred() -> void:
	var m := _main()
	var office: OfficeScene = m.get_node("OfficeSlot").get_child(0) as OfficeScene
	assert_not_null(office)
	assert_not_null(office.room())
	assert_eq(office.scale, Vector2(2, 2))
	assert_eq(office.position, Vector2(load("res://src/ui/main.gd").office_origin(office.room().pixel_size())))


func test_office_recentres_when_room_changes() -> void:
	var m := _main()
	var office: OfficeScene = m.get_node("OfficeSlot").get_child(0) as OfficeScene
	var st: GameState = GameRunner.session.state
	st.companies[st.player_company_id].office_id = &"office_small"
	EventBus.dispatch(&"project_changed", {})
	assert_eq(office.room().size_tiles, Vector2i(18, 9))
	assert_eq(office.position, Vector2(load("res://src/ui/main.gd").office_origin(office.room().pixel_size())))


func test_office_data_desks_lie_on_room_floor() -> void:
	var files: Array[String] = []
	for f: String in DirAccess.get_files_at("res://data/offices"):
		if f.ends_with(".tres"):
			files.append("res://data/offices/" + f)
	assert_gt(files.size(), 0)
	for path: String in files:
		var def: OfficeDef = load(path) as OfficeDef
		assert_not_null(def, path)
		var room: OfficeRoom = (load(def.scene_path) as PackedScene).instantiate() as OfficeRoom
		add_child_autofree(room)
		assert_eq(def.desk_positions.size(), def.seats, path)
		for cell: Vector2i in def.desk_positions:
			assert_true(room.is_floor(cell), "%s desk %s" % [path, cell])
			assert_true(room.is_floor(cell + Vector2i(0, 1)), "%s chair %s" % [path, cell])


func test_second_press_on_open_tab_closes_panel() -> void:
	var m := _main()
	var btn: Button = m.get_node("TabBarShell/Tab_market")
	btn.button_pressed = true
	assert_eq((m.get_node("PanelHost") as PanelHost).current_tab(), &"market")
	btn.button_pressed = false
	assert_eq((m.get_node("PanelHost") as PanelHost).current_tab(), &"")
	assert_false((m.get_node("PanelHost") as PanelHost).visible)


func test_debug_hud_does_not_block_clicks() -> void:
	var m := _main()
	assert_eq((m.get_node("DebugLayer/DebugHud") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_status_bar_date_money_visible_at_launch() -> void:
	var m := _main()
	await wait_process_frames(2)
	var bar: Control = m.get_node("StatusBar")
	for n: String in ["Date", "Money"]:
		var label: Label = bar.get_node("%" + n)
		assert_false(label.text.is_empty(), n)
		assert_gt(label.size.x, 30.0, n)
		assert_lte(label.get_global_rect().end.x, 640.0, n)


func test_status_bar_refreshes_after_game_loaded() -> void:
	var m := _main()
	var fresh: GameState = GameState.new_game(5, "Other", GameRunner.session.tuning)
	fresh.week = 60
	GameRunner.session = GameSession.new(fresh, GameRunner.session.tuning)
	EventBus.dispatch(&"game_loaded", {})
	assert_eq(m.get_node("StatusBar").get_node("%Date").text,
		StateQueries.date_text(fresh, GameRunner.session.tuning))
