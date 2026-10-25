extends GutTest

const DOCK_SCENE: PackedScene = preload("res://src/ui/hud/dock.tscn")


func after_each() -> void:
	TranslationServer.set_locale("en")


func _dock() -> Dock:
	var dock: Dock = DOCK_SCENE.instantiate()
	add_child_autofree(dock)
	return dock


func _tab(dock: Dock, id: StringName) -> Button:
	return dock.get_node("Row/Tab_%s" % id) as Button


func test_five_tabs_in_order_with_translated_text() -> void:
	var dock: Dock = _dock()
	var row: Node = dock.get_node("Row")
	assert_eq(row.get_child_count(), Dock.TABS.size())
	for i: int in Dock.TABS.size():
		var id: StringName = Dock.TABS[i]
		var btn: Button = row.get_child(i) as Button
		assert_eq(String(btn.name), "Tab_%s" % id)
		assert_eq(btn.text, tr("ui.tab.%s" % id))


func test_pressing_tab_emits_open() -> void:
	var dock: Dock = _dock()
	watch_signals(dock)
	_tab(dock, &"team").button_pressed = true
	assert_signal_emitted_with_parameters(dock, "tab_changed", [&"team"])
	assert_eq(dock.open_tab(), &"team")


func test_pressing_open_tab_again_closes() -> void:
	var dock: Dock = _dock()
	_tab(dock, &"team").button_pressed = true
	watch_signals(dock)
	_tab(dock, &"team").button_pressed = false
	assert_signal_emitted_with_parameters(dock, "tab_changed", [&""])
	assert_eq(dock.open_tab(), &"")


func test_switching_tabs_keeps_one_open() -> void:
	var dock: Dock = _dock()
	_tab(dock, &"team").button_pressed = true
	watch_signals(dock)
	_tab(dock, &"market").button_pressed = true
	assert_eq(dock.open_tab(), &"market")
	assert_false(_tab(dock, &"team").button_pressed)
	var params: Array = get_signal_parameters(dock, "tab_changed", get_signal_emit_count(dock, "tab_changed") - 1)
	assert_eq(params, [&"market"])


func test_close_all_emits_empty() -> void:
	var dock: Dock = _dock()
	_tab(dock, &"finance").button_pressed = true
	watch_signals(dock)
	dock.close_all()
	assert_signal_emitted_with_parameters(dock, "tab_changed", [&""])
	assert_eq(dock.open_tab(), &"")


func test_tabs_have_icons() -> void:
	var dock: Dock = _dock()
	for id: StringName in Dock.TABS:
		assert_eq(_tab(dock, id).icon, UiIcons.texture(id))


func test_labels_refresh_on_translation_change() -> void:
	var dock: Dock = _dock()
	TranslationServer.set_locale("th")
	dock.notification(NOTIFICATION_TRANSLATION_CHANGED)
	assert_eq(_tab(dock, &"team").text, tr("ui.tab.team"))
	assert_ne(_tab(dock, &"team").text, "Team")


func _check_fit(locale: String) -> void:
	TranslationServer.set_locale(locale)
	var screen: Control = Control.new()
	screen.size = Vector2(640, 360)
	add_child_autofree(screen)
	var dock: Dock = DOCK_SCENE.instantiate()
	screen.add_child(dock)
	dock.position = Vector2(70, 326)
	dock.size = Vector2(500, 30)
	await wait_frames(2)
	for id: StringName in Dock.TABS:
		assert_true(UiFit.button_fits(_tab(dock, id)), "%s fits (%s)" % [id, locale])
	assert_eq(dock.size.x, 500.0)
	assert_true(UiFit.inside_screen(dock))


func test_dock_labels_fit_en() -> void:
	await _check_fit("en")


func test_dock_labels_fit_th() -> void:
	await _check_fit("th")
