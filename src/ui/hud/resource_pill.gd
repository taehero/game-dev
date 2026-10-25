class_name ResourcePill
extends PanelContainer
## Rounded pill: coloured badge (icon or text) plus one value label.

@onready var _badge: IconBadge = %Badge
@onready var _value: Label = %Value


func _ready() -> void:
	_value.clip_text = true
	_value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func setup(icon: StringName, badge_text: String, color: Color, value_variation: StringName,
		tooltip_key: StringName, width: int) -> void:
	if icon == &"":
		_badge.set_text(badge_text, color)
	else:
		_badge.set_icon(icon, color)
	_value.theme_type_variation = value_variation
	custom_minimum_size.x = width
	tooltip_text = tr(tooltip_key)


func set_value(text: String) -> void:
	_value.text = text


func value_label() -> Label:
	return _value
