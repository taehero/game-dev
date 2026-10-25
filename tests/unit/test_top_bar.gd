extends GutTest

var _root: Control


func before_each() -> void:
	TranslationServer.set_locale("en")
	GameRunner.session = GameSession.new(Fixtures.new_state(1), Fixtures.tuning())


func after_each() -> void:
	GameRunner.session = null
	TranslationServer.set_locale("en")


func _bar() -> TopBar:
	_root = Control.new()
	_root.size = Vector2(640, 360)
	add_child_autofree(_root)
	var bar: TopBar = load("res://src/ui/hud/top_bar.tscn").instantiate()
	_root.add_child(bar)
	bar.anchor_right = 0.0
	bar.offset_left = 6
	bar.offset_top = 6
	bar.offset_right = 634
	bar.offset_bottom = 30
	return bar


func _st() -> GameState:
	return GameRunner.session.state


func _company() -> Company:
	return _st().companies[_st().player_company_id]


func test_pills_show_formatted_values() -> void:
	_company().money = 18450
	_company().fan_count = 1240
	var bar: TopBar = _bar()
	bar.refresh(_st(), GameRunner.session.tuning)
	assert_eq((bar.get_node("%Money") as ResourcePill).value_label().text, "18,450")
	assert_eq((bar.get_node("%Fans") as ResourcePill).value_label().text, "1,240")
	assert_eq((bar.get_node("%Date") as ResourcePill).value_label().text,
		StateQueries.date_text(_st(), GameRunner.session.tuning))


func test_pill_tooltips_translated() -> void:
	var bar: TopBar = _bar()
	assert_eq((bar.get_node("%Fans") as ResourcePill).tooltip_text, tr("ui.pill.fans"))


func _pressed_count(speed: SpeedControl) -> int:
	var n: int = 0
	for sp: int in SpeedControl.SPEEDS:
		if (speed.get_node("Row/Seg_%d" % sp) as Button).button_pressed:
			n += 1
	return n


func test_speed_segment_sets_speed_and_sync() -> void:
	var bar: TopBar = _bar()
	var speed: SpeedControl = bar.get_node("%Speed")
	speed.sync(1)
	GameRunner.session.speed = 1
	(speed.get_node("Row/Seg_2") as Button).pressed.emit()
	assert_eq(GameRunner.session.speed, 2)
	assert_eq(speed.active_speed(), 2)
	assert_eq(_pressed_count(speed), 1)


func test_auto_pause_shows_on_next_event() -> void:
	var bar: TopBar = _bar()
	var speed: SpeedControl = bar.get_node("%Speed")
	GameRunner.session.speed = 2
	EventBus.week_ticked.emit({})
	assert_eq(speed.active_speed(), 2)
	GameRunner.session.speed = 0
	EventBus.week_ticked.emit({})
	assert_eq(speed.active_speed(), 0)


func test_translation_change_updates_tooltip_and_segments() -> void:
	var bar: TopBar = _bar()
	TranslationServer.set_locale("th")
	bar.notification(Node.NOTIFICATION_TRANSLATION_CHANGED)
	assert_eq((bar.get_node("%Fans") as ResourcePill).tooltip_text, tr("ui.pill.fans"))
	assert_eq((bar.get_node("%Fans") as ResourcePill).tooltip_text, "แฟน")
	assert_eq((bar.get_node("%Speed/Row/Seg_1") as Button).text, tr("ui.hud.speed").format({"speed": 1}))
	assert_eq((bar.get_node("%Speed/Row/Seg_0") as Button).tooltip_text, "หยุด")


func test_sync_unknown_speed_presses_none() -> void:
	var bar: TopBar = _bar()
	var speed: SpeedControl = bar.get_node("%Speed")
	speed.sync(4)
	assert_eq(speed.active_speed(), 4)
	speed.sync(3)
	assert_eq(speed.active_speed(), -1)


func test_refreshes_from_replaced_session_on_game_loaded() -> void:
	var bar: TopBar = _bar()
	GameRunner.session.speed = 2
	EventBus.week_ticked.emit({})
	assert_eq((bar.get_node("%Speed") as SpeedControl).active_speed(), 2)
	var fresh: GameState = Fixtures.new_state(2)
	fresh.week = 60
	GameRunner.session = GameSession.new(fresh, Fixtures.tuning())
	GameRunner.session.speed = 0
	EventBus.game_loaded.emit({})
	assert_eq((bar.get_node("%Date") as ResourcePill).value_label().text,
		StateQueries.date_text(fresh, GameRunner.session.tuning))
	assert_eq((bar.get_node("%Speed") as SpeedControl).active_speed(), 0)


func _worst_case(locale: String) -> void:
	TranslationServer.set_locale(locale)
	var pid: int = Fixtures.add_project(_st(), {"phase": Project.Phase.PRODUCTION})
	_st().projects[pid].hype = 9999
	var bar: TopBar = _bar()
	await get_tree().process_frame
	await get_tree().process_frame
	for money: int in [1234567, -1234567]:
		for week: int in [519, 520]:
			_company().money = money
			_company().fan_count = 1234567
			_st().week = week
			bar.refresh(_st(), GameRunner.session.tuning)
			await get_tree().process_frame
			for n: String in ["Date", "Money", "Fans", "Hype"]:
				var pill: ResourcePill = bar.get_node("%" + n)
				var label: Label = pill.value_label()
				assert_true(UiFit.text_fits(label), "%s %s fits (%s, %d, w%d)" % [locale, n, label.text, money, week])
				assert_true(UiFit.inside_screen(pill), n + " inside screen")
			assert_true(UiFit.inside_screen(bar.get_node("%Speed")))
			var hype: Control = bar.get_node("%Hype")
			var speed: Control = bar.get_node("%Speed")
			assert_true(hype.get_global_rect().end.x <= speed.get_global_rect().position.x - 6)


func test_pills_fit_worst_case_en() -> void:
	await _worst_case("en")


func test_pills_fit_worst_case_th() -> void:
	await _worst_case("th")


func test_set_speed_zero_updates_control_without_tick() -> void:
	var bar: TopBar = _bar()
	var speed: SpeedControl = bar.get_node("%Speed")
	GameRunner.set_speed(4)
	GameRunner._process(0.0)
	assert_eq(speed.active_speed(), 4)
	var week: int = _st().week
	GameRunner.set_speed(0)
	GameRunner._process(0.0)
	assert_eq(speed.active_speed(), 0)
	assert_eq(_st().week, week)


func test_popup_pause_and_resume_sync_control() -> void:
	var bar: TopBar = _bar()
	var speed: SpeedControl = bar.get_node("%Speed")
	GameRunner.set_speed(4)
	GameRunner.pause_for_popup()
	GameRunner._process(0.0)
	assert_eq(speed.active_speed(), 0)
	GameRunner.resume_after_popup()
	GameRunner._process(0.0)
	assert_eq(speed.active_speed(), 4)


func test_one_click_sets_speed_once() -> void:
	var bar: TopBar = _bar()
	var speed: SpeedControl = bar.get_node("%Speed")
	GameRunner.session.drain_events()
	(speed.get_node("Row/Seg_2") as Button).pressed.emit()
	var changes: int = 0
	for e: Dictionary in GameRunner.session.drain_events():
		if e["name"] == &"speed_changed":
			changes += 1
	assert_eq(changes, 1)
