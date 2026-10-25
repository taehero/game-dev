class_name IconBadge
extends PanelContainer
## 16x16 coloured circle showing either an icon glyph or a short text.

@onready var _glyph: TextureRect = %Glyph
@onready var _text: Label = %Text


func set_icon(icon: StringName, bg: Color) -> void:
	_apply_bg(bg)
	_glyph.texture = UiIcons.texture(icon)
	_glyph.visible = true
	_text.visible = false


func set_text(text: String, bg: Color) -> void:
	_apply_bg(bg)
	for side: String in ["left", "top", "right", "bottom"]:
		var sb: StyleBoxFlat = get_theme_stylebox(&"panel") as StyleBoxFlat
		sb.set("content_margin_" + side, 0.0)
	_text.text = text
	_text.visible = true
	_glyph.visible = false


func _apply_bg(bg: Color) -> void:
	var base: StyleBoxFlat = get_theme_stylebox(&"panel") as StyleBoxFlat
	var sb: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	sb.bg_color = bg
	add_theme_stylebox_override(&"panel", sb)
