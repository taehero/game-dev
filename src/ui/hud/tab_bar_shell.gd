class_name TabBarShell
extends HBoxContainer

signal tab_changed(tab: StringName)

const TABS: Array[StringName] = [&"project", &"team", &"equipment", &"finance", &"market"]
const BAR_HEIGHT: int = 22

var _group: ButtonGroup = ButtonGroup.new()
var _last_emitted: StringName = &""


func _ready() -> void:
	custom_minimum_size = Vector2(0, BAR_HEIGHT)
	_group.allow_unpress = true
	for id: StringName in TABS:
		var btn: Button = Button.new()
		btn.name = "Tab_%s" % id
		btn.toggle_mode = true
		btn.button_group = _group
		btn.text = tr("ui.tab.%s" % id)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggled.connect(_on_toggled)
		add_child(btn)


func open_tab() -> StringName:
	for id: StringName in TABS:
		var btn: Button = get_node_or_null("Tab_%s" % id) as Button
		if btn != null and btn.button_pressed:
			return id
	return &""


func _on_toggled(_pressed: bool) -> void:
	_sync()


func _sync() -> void:
	var now: StringName = open_tab()
	if now != _last_emitted:
		_last_emitted = now
		tab_changed.emit(now)
