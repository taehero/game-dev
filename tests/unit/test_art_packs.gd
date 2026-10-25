extends GutTest

const ICONS: Array[String] = ["home", "multiplayer", "star", "pause", "gamepad", "wrench", "leaderboardsComplex", "trophy", "cross"]
const PACKS: Dictionary[String, Array] = {
	"kenney_modern_city": ["tilemap_packed.png", "License.txt"],
	"kenney_indoors": ["roguelikeIndoor_transparent.png", "License.txt"],
	"kenney_urban": ["tilemap_packed.png", "License.txt"],
	"kenney_emotes": ["pixel_style1.png", "License.txt"],
	"kenney_game_icons": [
		"home.png", "multiplayer.png", "star.png", "pause.png", "gamepad.png",
		"wrench.png", "leaderboardsComplex.png", "trophy.png", "cross.png", "License.txt",
	],
}
const SIZES: Dictionary[String, Vector2i] = {
	"res://assets/art/kenney_modern_city/tilemap_packed.png": Vector2i(592, 448),
	"res://assets/art/kenney_indoors/roguelikeIndoor_transparent.png": Vector2i(458, 305),
	"res://assets/art/kenney_urban/tilemap_packed.png": Vector2i(432, 288),
	"res://assets/art/kenney_emotes/pixel_style1.png": Vector2i(160, 48),
}
const URLS: Dictionary[String, String] = {
	"kenney_modern_city": "https://kenney.nl/assets/roguelike-modern-city",
	"kenney_indoors": "https://kenney.nl/assets/roguelike-indoors",
	"kenney_urban": "https://kenney.nl/assets/rpg-urban-pack",
	"kenney_emotes": "https://kenney.nl/assets/emotes-pack",
	"kenney_game_icons": "https://kenney.nl/assets/game-icons",
}

func test_every_pack_present_with_cc0_licence() -> void:
	for slug: String in PACKS:
		for f: String in PACKS[slug]:
			assert_true(FileAccess.file_exists("res://assets/art/%s/%s" % [slug, f]), "%s/%s" % [slug, f])
		var lic := FileAccess.get_file_as_string("res://assets/art/%s/License.txt" % slug)
		assert_string_contains(lic.to_upper(), "CC0")

func test_sheet_sizes_match_ruling() -> void:
	for path: String in SIZES:
		assert_eq((load(path) as Texture2D).get_size(), Vector2(SIZES[path]), path)
	for icon: String in ICONS:
		var p := "res://assets/art/kenney_game_icons/%s.png" % icon
		assert_eq((load(p) as Texture2D).get_size(), Vector2(50, 50), p)

func test_credits_rows_for_new_packs() -> void:
	var credits := FileAccess.get_file_as_string("res://assets/CREDITS.md")
	for slug: String in URLS:
		assert_string_contains(credits, slug)
		assert_string_contains(credits, URLS[slug])
