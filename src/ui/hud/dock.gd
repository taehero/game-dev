class_name Dock
extends PanelContainer
## Floating bottom dock with the five management tabs.

signal tab_changed(tab: StringName)

const TABS: Array[StringName] = [&"project", &"team", &"equipment", &"finance", &"market"]

var _group: ButtonGroup = ButtonGroup.new()
var _last_emitted: StringName = &""


func _ready() -> void:
	_group.allow_unpress = true
	var row: HBoxContainer = get_node("Row") as HBoxContainer
	for id: StringName in TABS:
		var btn: Button = Button.new()
		btn.name = "Tab_%s" % id
		btn.theme_type_variation = &"DockButton"
		btn.toggle_mode = true
		btn.button_group = _group
		btn.icon = UiIcons.texture(id)
		btn.text = tr("ui.tab.%s" % id)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggled.connect(_on_toggled)
		row.add_child(btn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		for id: StringName in TABS:
			var btn: Button = get_node_or_null("Row/Tab_%s" % id) as Button
			if btn != null:
				btn.text = tr("ui.tab.%s" % id)


func open_tab() -> StringName:
	for id: StringName in TABS:
		var btn: Button = get_node_or_null("Row/Tab_%s" % id) as Button
		if btn != null and btn.button_pressed:
			return id
	return &""


func close_all() -> void:
	var btn: Button = get_node_or_null("Row/Tab_%s" % open_tab()) as Button
	if btn != null:
		btn.button_pressed = false
	_sync()


func _on_toggled(_pressed: bool) -> void:
	_sync()


func _sync() -> void:
	var now: StringName = open_tab()
	if now != _last_emitted:
		_last_emitted = now
		tab_changed.emit(now)
