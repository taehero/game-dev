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
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.text = tr("ui.tab.%s" % id)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.toggled.connect(_on_toggled)
		btn.resized.connect(_centre_content.bind(btn))
		row.add_child(btn)


## Icon and label stay grouped: left-align and pad so the group sits in the middle.
func _centre_content(btn: Button) -> void:
	if not btn.is_inside_tree():
		return
	var font: Font = btn.get_theme_font(&"font")
	var text_w: float = font.get_string_size(btn.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		btn.get_theme_font_size(&"font_size")).x
	var icon_w: float = float(btn.get_theme_constant(&"icon_max_width"))
	var group_w: float = text_w + icon_w + float(btn.get_theme_constant(&"h_separation"))
	for sb_name: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var meta_key: StringName = StringName("base_%s" % sb_name)
		if not btn.has_meta(meta_key):
			btn.set_meta(meta_key, btn.get_theme_stylebox(sb_name, &"DockButton"))
		var base: StyleBox = btn.get_meta(meta_key) as StyleBox
		var sb: StyleBox = base.duplicate() as StyleBox
		var pad: float = maxf(0.0, (btn.size.x - group_w) / 2.0)
		sb.content_margin_left = pad
		sb.content_margin_right = 0.0
		btn.add_theme_stylebox_override(sb_name, sb)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		for id: StringName in TABS:
			var btn: Button = get_node_or_null("Row/Tab_%s" % id) as Button
			if btn != null:
				btn.text = tr("ui.tab.%s" % id)
				_centre_content(btn)


func open_tab() -> StringName:
	for id: StringName in TABS:
		var btn: Button = get_node_or_null("Row/Tab_%s" % id) as Button
		if btn != null and btn.button_pressed:
			return id
	return &""


## Code-driven open: selects `tab` (or closes with &""). Emits tab_changed once, like a click.
func select(tab: StringName) -> void:
	if tab == &"" or not TABS.has(tab):
		close_all()
		return
	var btn: Button = get_node_or_null("Row/Tab_%s" % tab) as Button
	if btn != null:
		btn.button_pressed = true
	_sync()


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
