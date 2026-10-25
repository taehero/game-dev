class_name SpeedControl
extends PanelContainer
## Segmented pause / 1x / 2x / 4x control. Writes only through GameRunner.set_speed.

const SPEEDS: Array[int] = [0, 1, 2, 4]

var _group: ButtonGroup = ButtonGroup.new()


func _ready() -> void:
	custom_minimum_size.x = 114
	_group.allow_unpress = false
	var row: HBoxContainer = %Row
	for s: int in SPEEDS:
		var seg := Button.new()
		seg.name = "Seg_%d" % s
		seg.theme_type_variation = &"SegmentButton"
		seg.toggle_mode = true
		seg.button_group = _group
		seg.custom_minimum_size.x = 26
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(seg)
		seg.pressed.connect(_choose.bind(s))
		seg.toggled.connect(func(on: bool) -> void:
			if on:
				_choose(s))
	_translate()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_translate()


func _translate() -> void:
	for s: int in SPEEDS:
		var seg: Button = _seg(s)
		if s == 0:
			seg.icon = UiIcons.texture(&"pause")
			seg.expand_icon = true
			seg.text = ""
			seg.tooltip_text = tr("ui.hud.pause")
		else:
			seg.text = tr("ui.hud.speed").format({"speed": s})


func _seg(s: int) -> Button:
	return (%Row as Node).get_node("Seg_%d" % s) as Button


func _choose(s: int) -> void:
	_seg(s).set_pressed_no_signal(true)
	if GameRunner.session != null:
		GameRunner.set_speed(s)


func sync(speed: int) -> void:
	for s: int in SPEEDS:
		_seg(s).set_pressed_no_signal(s == speed)


func active_speed() -> int:
	for s: int in SPEEDS:
		if _seg(s).button_pressed:
			return s
	return -1
