extends GutTest

const HOST_SCENE: PackedScene = preload("res://src/ui/panels/panel_host.tscn")


func after_each() -> void:
	TranslationServer.set_locale("en")


func _host() -> PanelHost:
	var host: PanelHost = HOST_SCENE.instantiate()
	add_child_autofree(host)
	return host


func test_title_refreshes_on_translation_change() -> void:
	var host: PanelHost = _host()
	host.show_tab(&"project")
	var title: Label = host.get_node("%PanelTitle")
	var before: String = title.text
	TranslationServer.set_locale("th")
	host.notification(NOTIFICATION_TRANSLATION_CHANGED)
	assert_eq(title.text, tr("ui.tab.project"))
	assert_ne(title.text, before)


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


func test_rest_rect_is_centred_above_dock() -> void:
	var host: PanelHost = _host()
	host.show_tab(&"team")
	await wait_seconds(PanelHost.SLIDE_S + 0.05)
	assert_eq(host.position, Vector2(70, 34))
	assert_eq(host.size, Vector2(500, 286))
	assert_true(host.position.y + host.size.y <= 326 - 4)


func test_close_button_requests_close() -> void:
	var host: PanelHost = _host()
	watch_signals(host)
	(host.get_node("%Close") as Button).pressed.emit()
	assert_signal_emitted(host, "close_requested")
