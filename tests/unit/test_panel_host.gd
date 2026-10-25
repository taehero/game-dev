extends GutTest


func after_each() -> void:
	TranslationServer.set_locale("en")


func test_title_refreshes_on_translation_change() -> void:
	var host: PanelHost = add_child_autofree((load("res://src/ui/panels/panel_host.tscn") as PackedScene).instantiate())
	host.show_tab(&"project")
	var title: Label = host.get_node("%PanelTitle")
	var before: String = title.text
	TranslationServer.set_locale("th")
	host.notification(NOTIFICATION_TRANSLATION_CHANGED)
	assert_eq(title.text, tr("ui.tab.project"))
	assert_ne(title.text, before)
