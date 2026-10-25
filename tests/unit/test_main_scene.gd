extends GutTest


func before_all() -> void:
	Fixtures.use_real_content()


func after_all() -> void:
	ContentDB.use(Fixtures.content())


func after_each() -> void:
	GameRunner.session = null


func _main() -> Control:
	return add_child_autofree(load("res://src/ui/main.tscn").instantiate())


func test_f3_toggles_debug_hud() -> void:
	var m := _main()
	var ev := InputEventKey.new()
	ev.keycode = KEY_F3
	ev.pressed = true
	m._unhandled_input(ev)
	assert_true(m.get_node("DebugLayer/DebugHud").visible)
	m._unhandled_input(ev)
	assert_false(m.get_node("DebugLayer/DebugHud").visible)


func test_project_theme_is_main_theme() -> void:
	assert_eq(String(ProjectSettings.get_setting("gui/theme/custom")), "res://src/ui/theme/main_theme.tres")


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


func test_debug_hud_does_not_block_clicks() -> void:
	var m := _main()
	assert_eq((m.get_node("DebugLayer/DebugHud") as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_main_has_hud_and_hidden_debug_hud() -> void:
	var m := _main()
	for n: String in ["TopBar", "ProjectCard", "Dock", "PanelHost", "Popups", "OfficeSlot"]:
		assert_not_null(m.get_node_or_null(n), n)
	assert_null(m.get_node_or_null("StatusBar"))
	assert_null(m.get_node_or_null("TabBarShell"))
	assert_false(m.get_node("DebugLayer/DebugHud").visible)


func test_office_origin_centres_rooms() -> void:
	var main_script: GDScript = load("res://src/ui/main.gd")
	assert_eq(main_script.office_origin(Vector2i(192, 128)), Vector2i(160, 50))
	assert_eq(main_script.office_origin(Vector2i(288, 144)), Vector2i(64, 34))


func test_dock_opens_panel_host() -> void:
	var m := _main()
	(m.get_node("Dock") as Dock).select(&"market")
	assert_eq((m.get_node("PanelHost") as PanelHost).current_tab(), &"market")


func test_second_press_on_open_tab_closes_panel() -> void:
	var m := _main()
	var btn: Button = m.get_node("Dock/Row/Tab_market")
	btn.button_pressed = true
	assert_eq((m.get_node("PanelHost") as PanelHost).current_tab(), &"market")
	btn.button_pressed = false
	assert_eq((m.get_node("PanelHost") as PanelHost).current_tab(), &"")
	assert_false((m.get_node("PanelHost") as PanelHost).visible)


func test_panel_close_releases_dock() -> void:
	var m := _main()
	(m.get_node("Dock") as Dock).select(&"market")
	m.get_node("PanelHost").get_node("%Close").pressed.emit()
	assert_eq((m.get_node("Dock") as Dock).open_tab(), &"")
	assert_false((m.get_node("PanelHost") as PanelHost).visible)


func test_top_bar_filled_at_launch() -> void:
	var m := _main()
	var st: GameState = GameRunner.session.state
	assert_eq(m.get_node("TopBar").get_node("%Date").value_label().text,
		StateQueries.date_text(st, GameRunner.session.tuning))


func test_top_bar_refreshes_after_game_loaded() -> void:
	var m := _main()
	var fresh: GameState = GameState.new_game(5, "Other", GameRunner.session.tuning)
	fresh.week = 60
	GameRunner.session = GameSession.new(fresh, GameRunner.session.tuning)
	EventBus.dispatch(&"game_loaded", {})
	assert_eq(m.get_node("TopBar").get_node("%Date").value_label().text,
		StateQueries.date_text(fresh, GameRunner.session.tuning))


func test_card_subtitle_uses_content_names() -> void:
	var m := _main()
	var st: GameState = GameRunner.session.state
	var cmd: StartProjectCommand = StartProjectCommand.game(
		StateQueries.player_company_id(st), "Star Run", &"size_small", &"platform_nova8",
		&"topic_space", &"genre_action", -1, &"lic_engine_homebrew", [] as Array[StringName])
	assert_true(GameRunner.submit(cmd).ok)
	EventBus.dispatch(&"project_changed", {})
	var expected: String = tr(ContentDB.active().genres[&"genre_action"].name_key)
	assert_true((m.get_node("ProjectCard").get_node("%Subtitle") as Label).text.contains(expected))


func test_show_popup_mounts_under_popups() -> void:
	var m := _main()
	var popup: PopupCard = load("res://src/ui/panels/popup_card.tscn").instantiate() as PopupCard
	m.show_popup(popup)
	assert_eq(popup.get_parent(), m.get_node("Popups"))


func test_debug_hud_only_buttons_take_mouse() -> void:
	var m := _main()
	var stack: Array[Node] = [m.get_node("DebugLayer/DebugHud")]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Control and not n is BaseButton:
			assert_eq((n as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(n.get_path()))


func _worst_case(locale: String) -> void:
	TranslationServer.set_locale(locale)
	var m := _main()
	var st: GameState = GameRunner.session.state
	var company: Company = st.companies[st.player_company_id]
	company.fan_count = 1234567
	var pid: int = Fixtures.add_project(st, {
		"title": "เกมผจญภัยอวกาศที่ยาวมากมาย", "phase": Project.Phase.PRODUCTION, "stage_index": 2,
		"stage_progress": 9900, "bugs": 9999,
	})
	st.projects[pid].hype = 9999
	for k: StringName in [&"design", &"tech", &"art", &"audio"]:
		st.projects[pid].points[k] = 9999
	for money: int in [1234567, -1234567]:
		for week: int in [519, 520]:
			company.money = money
			st.week = week
			EventBus.dispatch(&"project_changed", {})
			await wait_process_frames(2)
			_assert_screen_fits(m, locale)
	TranslationServer.set_locale("en")


func _assert_screen_fits(m: Control, locale: String) -> void:
	var bar: Control = m.get_node("TopBar")
	var card: Control = m.get_node("ProjectCard").get_node("%Card")
	var dock: Control = m.get_node("Dock")
	var parts: Array[Control] = [bar, card, dock]
	for c: Control in parts:
		assert_true(UiFit.inside_screen(c), "%s inside (%s)" % [c.name, locale])
	for i: int in parts.size():
		for j: int in range(i + 1, parts.size()):
			assert_false(parts[i].get_global_rect().intersects(parts[j].get_global_rect()),
				"%s overlaps %s (%s)" % [parts[i].name, parts[j].name, locale])
	assert_false(Rect2(PanelHost.REST_POS, PanelHost.REST_SIZE).intersects(dock.get_global_rect()))
	var labels: Array[Label] = UiFit.labels_under(bar)
	labels.append_array(UiFit.labels_under(m.get_node("ProjectCard")))
	for l: Label in labels:
		if l.name == &"Title":
			continue
		assert_true(UiFit.text_fits(l), "%s '%s' (%s)" % [l.get_path(), l.text, locale])
	for id: StringName in Dock.TABS:
		assert_true(UiFit.button_fits(dock.get_node("Row/Tab_%s" % id)), "%s (%s)" % [id, locale])


func test_screen_fits_worst_case_en() -> void:
	await _worst_case("en")


func test_screen_fits_worst_case_th() -> void:
	await _worst_case("th")


func test_project_card_hidden_while_panel_open() -> void:
	var m := _main()
	var card: Control = m.get_node("ProjectCard")
	assert_true(card.visible)
	var btn: Button = m.get_node("Dock/Row/Tab_finance")
	btn.button_pressed = true
	assert_false(card.visible)
	btn.button_pressed = false
	assert_true(card.visible)
