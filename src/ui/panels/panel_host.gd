class_name PanelHost
extends Control

signal close_requested

const SLIDE_FROM: float = 326.0
const SLIDE_S: float = 0.15
const REST_POS: Vector2 = Vector2(70, 34)
const REST_SIZE: Vector2 = Vector2(500, 286)

var _panels: Dictionary[StringName, Control] = {}
var _current: StringName = &""
var _tween: Tween


func _ready() -> void:
	position = REST_POS
	size = REST_SIZE
	visible = false
	var close_btn: Button = get_node("%Close") as Button
	UiIcons.style_close_button(close_btn)
	close_btn.tooltip_text = tr("ui.popup.close")
	close_btn.pressed.connect(func() -> void: close_requested.emit())


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		(get_node("%Close") as Button).tooltip_text = tr("ui.popup.close")
		if _current != &"":
			(get_node("%PanelTitle") as Label).text = tr("ui.tab.%s" % _current)


func set_panel(tab: StringName, panel: Control) -> void:
	var content: Control = get_node("%Content") as Control
	if panel.get_parent() != null:
		panel.get_parent().remove_child(panel)
	content.add_child(panel)
	panel.visible = tab == _current and visible
	_panels[tab] = panel


func show_tab(tab: StringName) -> void:
	_current = tab
	(get_node("%PanelTitle") as Label).text = tr("ui.tab.%s" % tab)
	for key: StringName in _panels:
		_panels[key].visible = key == tab
	visible = true
	if _tween != null:
		_tween.kill()
	position = Vector2(REST_POS.x, SLIDE_FROM)
	size = REST_SIZE
	_tween = create_tween()
	_tween.tween_property(self, "position:y", REST_POS.y, SLIDE_S)
	_tween.tween_callback(_snap_to_rest)


func hide_panel() -> void:
	if _tween != null:
		_tween.kill()
	_current = &""
	visible = false
	_snap_to_rest()
	for key: StringName in _panels:
		_panels[key].visible = false


func current_tab() -> StringName:
	return _current


func _snap_to_rest() -> void:
	position = REST_POS
	size = REST_SIZE
