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
