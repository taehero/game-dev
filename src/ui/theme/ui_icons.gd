class_name UiIcons
extends RefCounted
## Icon registry: logical name to Kenney Game Icons texture.

const DIR := "res://assets/art/kenney_game_icons/"
const FILES: Dictionary[StringName, String] = {
	&"date": "home.png",
	&"fans": "multiplayer.png",
	&"hype": "star.png",
	&"pause": "pause.png",
	&"project": "gamepad.png",
	&"team": "multiplayer.png",
	&"equipment": "wrench.png",
	&"finance": "leaderboardsComplex.png",
	&"market": "trophy.png",
	&"close": "cross.png",
}


static func texture(icon: StringName) -> Texture2D:
	if not FILES.has(icon):
		push_warning("UiIcons: unknown icon '%s'" % icon)
		return null
	return load(DIR + FILES[icon]) as Texture2D


## Shared close-glyph styling for panel and popup headers (18x18 flat button).
static func style_close_button(btn: Button) -> void:
	btn.icon = texture(&"close")
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	btn.add_theme_color_override(&"icon_normal_color", UiPalette.TEXT_MUTED)
	btn.add_theme_color_override(&"icon_hover_color", UiPalette.TEXT)
	btn.add_theme_color_override(&"icon_pressed_color", UiPalette.ACCENT)
	var pad: StyleBoxEmpty = StyleBoxEmpty.new()
	pad.set_content_margin_all(3)
	for sb: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		btn.add_theme_stylebox_override(sb, pad)
