class_name IconBadge
extends PanelContainer
## 16x16 coloured circle showing either an icon glyph or a short text.
## Safe to configure before the node enters the tree; applied in _ready.

var _icon: StringName = &""
var _label: String = ""
var _bg: Color = Color.WHITE
var _use_text: bool = false
var _configured: bool = false

@onready var _glyph: TextureRect = %Glyph
@onready var _text: Label = %Text


func set_icon(icon: StringName, bg: Color) -> void:
	_icon = icon
	_bg = bg
	_use_text = false
	_configured = true
	_apply()


func set_text(text: String, bg: Color) -> void:
	_label = text
	_bg = bg
	_use_text = true
	_configured = true
	_apply()


func _ready() -> void:
	_apply()


func _apply() -> void:
	if not is_node_ready() or not _configured:
		return
	# Drop any previous override so the copy starts from the theme stylebox.
	remove_theme_stylebox_override(&"panel")
	var sb: StyleBoxFlat = (get_theme_stylebox(&"panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	sb.bg_color = _bg
	if _use_text:
		sb.content_margin_left = 0.0
		sb.content_margin_top = 0.0
		sb.content_margin_right = 0.0
		sb.content_margin_bottom = 0.0
		_text.text = _label
	else:
		_glyph.texture = UiIcons.texture(_icon)
	add_theme_stylebox_override(&"panel", sb)
	_text.visible = _use_text
	_glyph.visible = not _use_text
	# Size never shrinks on its own after a transiently larger minimum.
	reset_size()
