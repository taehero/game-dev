extends GutTest

const BAR_SCENE: PackedScene = preload("res://src/ui/hud/tab_bar_shell.tscn")
const HOST_SCENE: PackedScene = preload("res://src/ui/panels/panel_host.tscn")


func _bar() -> TabBarShell:
	var bar: TabBarShell = BAR_SCENE.instantiate()
	add_child_autofree(bar)
	return bar


func _host() -> PanelHost:
	var host: PanelHost = HOST_SCENE.instantiate()
	add_child_autofree(host)
	return host


func _tab(bar: TabBarShell, id: StringName) -> Button:
	return bar.get_node("Tab_%s" % id) as Button


func test_five_tabs_in_order_with_translated_text() -> void:
	var bar: TabBarShell = _bar()
	assert_eq(bar.get_child_count(), TabBarShell.TABS.size())
	for i: int in TabBarShell.TABS.size():
		var id: StringName = TabBarShell.TABS[i]
		var btn: Button = bar.get_child(i) as Button
		assert_eq(String(btn.name), "Tab_%s" % id)
		assert_eq(btn.text, tr("ui.tab.%s" % id))


func test_pressing_tab_emits_open() -> void:
	var bar: TabBarShell = _bar()
	watch_signals(bar)
	_tab(bar, &"team").button_pressed = true
	assert_signal_emitted_with_parameters(bar, "tab_changed", [&"team"])
	assert_eq(bar.open_tab(), &"team")


func test_pressing_open_tab_again_closes() -> void:
	var bar: TabBarShell = _bar()
	_tab(bar, &"team").button_pressed = true
	watch_signals(bar)
	_tab(bar, &"team").button_pressed = false
	assert_signal_emitted_with_parameters(bar, "tab_changed", [&""])
	assert_eq(bar.open_tab(), &"")


func test_switching_tabs_keeps_one_open() -> void:
	var bar: TabBarShell = _bar()
	_tab(bar, &"team").button_pressed = true
	watch_signals(bar)
	_tab(bar, &"market").button_pressed = true
	assert_eq(bar.open_tab(), &"market")
	assert_false(_tab(bar, &"team").button_pressed)
	var params: Array = get_signal_parameters(bar, "tab_changed", get_signal_emit_count(bar, "tab_changed") - 1)
	assert_eq(params, [&"market"])


func test_panel_host_shows_title_and_registered_panel() -> void:
	var host: PanelHost = _host()
	var label: Label = Label.new()
	host.set_panel(&"finance", label)
	host.show_tab(&"finance")
	assert_true(host.visible)
	assert_eq((host.get_node("%PanelTitle") as Label).text, tr("ui.tab.finance"))
	assert_true(label.visible)
	host.show_tab(&"team")
	assert_false(label.visible)
	assert_eq(host.current_tab(), &"team")


func test_hide_panel() -> void:
	var host: PanelHost = _host()
	host.show_tab(&"team")
	host.hide_panel()
	assert_false(host.visible)
	assert_eq(host.current_tab(), &"")


func test_labels_refresh_on_translation_change() -> void:
	var bar: TabBarShell = _bar()
	var saved: String = TranslationServer.get_locale()
	TranslationServer.set_locale("th")
	bar.notification(NOTIFICATION_TRANSLATION_CHANGED)
	assert_eq(_tab(bar, &"team").text, tr("ui.tab.team"))
	assert_ne(_tab(bar, &"team").text, "Team")
	TranslationServer.set_locale(saved)
