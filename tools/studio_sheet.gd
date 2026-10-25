class_name StudioSheet
extends RefCounted
## Generates the studio sprite sheet: three fictional computers, two floors, one wall top.

const OUT_PATH: String = "res://assets/art/studio/computers.png"
const CELL: int = 16
const COLS: int = 3
const ROWS: int = 2

const PALETTE: Dictionary[String, Color] = {
	"o": Color("#3b2f2f"), "b": Color("#d9cfae"), "B": Color("#b7aa86"), "k": Color("#1d2a22"),
	"g": Color("#58e07a"), "G": Color("#2f9a4c"), "w": Color("#f2eee0"), "s": Color("#8e9aa6"),
	"S": Color("#5d6b78"), "c": Color("#7fd0ff"), "C": Color("#3b8fd0"), "y": Color("#ffd65a"),
}
const TIER_1: Array[String] = [
	"................", "..oooooooooooo..", "..obbbbbbbbbbo..", "..obkkkkkkkkbo..",
	"..obkgggGkkkbo..", "..obkGggggkkbo..", "..obkggGkkkkbo..", "..obkkkkkkkkbo..",
	"..obbbbbbbbBbo..", "..oooooooooooo..", ".oooooooooooooo.", ".obwbwbwbwbwbBo.",
	".oBBBBBBBBBBBBo.", ".oooooooooooooo.", "................", "................",
]
const TIER_2: Array[String] = [
	"................", "...oooooooooo...", "...obbbbbbbbo...", "...obkkkkkkbo...",
	"...obkcckkkbo...", "...obkcCcckbo...", "...obkkkkkkbo...", "...obbbbbbBbo...",
	"...oooooooooo...", "..oBBBBBBBBBBo..", "..oooooooooooo..", ".oooooooooooooo.",
	".obwbwbwbwbwbBo.", ".oooooooooooooo.", "................", "................",
]
const TIER_3: Array[String] = [
	"................", ".oooooooooooooo.", ".oSSSSSSSSSSSSo.", ".oSCCCCCCCCCCSo.",
	".oSCwwwwCCCCCSo.", ".oSCwccwCyyyCSo.", ".oSCwwwwCyyyCSo.", ".oSCCCCCCCCCCSo.",
	".oSSSSSSSSSSSSo.", ".oooooooooooooo.", "......oSSo......", ".....oooooo.....",
	".oooooooooooooo.", ".oswswswswswsSo.", ".oooooooooooooo.", "................",
]
const COMPUTERS: Array = [TIER_1, TIER_2, TIER_3]

const WOOD_A: Color = Color("#dcae72")
const WOOD_B: Color = Color("#d2a265")
const WOOD_SEAM: Color = Color("#b98a55")
const CARPET: Color = Color("#5b6b8c")
const CARPET_DOT: Color = Color("#66779a")
const WALL: Color = Color("#6d6a60")
const WALL_LIGHT: Color = Color("#8a867a")
const WALL_DARK: Color = Color("#4f4c45")


static func build() -> Image:
	var img := Image.create_empty(CELL * COLS, CELL * ROWS, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for tier: int in range(COMPUTERS.size()):
		var rows: Array = COMPUTERS[tier]
		for y: int in range(CELL):
			var row: String = rows[y]
			for x: int in range(CELL):
				var ch: String = row[x]
				if ch != ".":
					img.set_pixel(tier * CELL + x, y, PALETTE[ch])
	for y: int in range(CELL):
		for x: int in range(CELL):
			img.set_pixel(x, CELL + y, _wood(x, y))
			img.set_pixel(CELL + x, CELL + y, _carpet(x, y))
			img.set_pixel(2 * CELL + x, CELL + y, _wall(x, y))
	return img


static func _wood(x: int, y: int) -> Color:
	# Long planks: 8px tall, one end joint per tile, staggered between rows.
	var plank_row: int = y / 8
	if y % 8 == 7 or x == (plank_row * 8) % 16:
		return WOOD_SEAM
	return WOOD_A if plank_row % 2 == 0 else WOOD_B


static func _carpet(x: int, y: int) -> Color:
	return CARPET_DOT if (x + 2 * y) % 4 == 0 else CARPET


static func _wall(x: int, y: int) -> Color:
	if y == 15:
		return WALL_DARK
	if y == 0 or x == 0:
		return WALL_LIGHT
	return WALL
