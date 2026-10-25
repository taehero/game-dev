class_name OfficeArt
extends RefCounted
## Single source of art coordinates (Kenney 1-Bit Pack, colored_packed.png, CC0).
## Cells are (column, row) in 16 px tiles; the sheet is 49 x 22 with no spacing.

const TILE: int = 16
const SHEET_PATH: String = "res://assets/art/kenney_1bit/colored_packed.png"
const MARGIN: Vector2i = Vector2i(0, 0)
const SEPARATION: Vector2i = Vector2i(0, 0)

const FLOORS: Dictionary[StringName, Vector2i] = {
	&"concrete": Vector2i(2, 0),
	&"wood": Vector2i(16, 0),
}
const WALL_TOP: Vector2i = Vector2i(18, 0)
const WALL_FACE: Vector2i = Vector2i(0, 13)
const WALL_SIDE: Vector2i = Vector2i(18, 1)
const WALL_BOTTOM: Vector2i = Vector2i(18, 2)

const DESK: Vector2i = Vector2i(2, 8)
## Index 0 = tier 1. Terminal, monitor on stand, flat monitor.
const COMPUTERS: Array[Vector2i] = [Vector2i(8, 8), Vector2i(17, 10), Vector2i(0, 12)]
const STAFF_BODIES: Array[Vector2i] = [
	Vector2i(24, 4), Vector2i(25, 4), Vector2i(27, 4), Vector2i(28, 8),
]

static var _tileset: TileSet = null


static func region(cell: Vector2i) -> Rect2i:
	return Rect2i(MARGIN + cell * (Vector2i(TILE, TILE) + SEPARATION), Vector2i(TILE, TILE))


static func atlas(cell: Vector2i) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = load(SHEET_PATH) as Texture2D
	tex.region = Rect2(region(cell))
	return tex


static func computer_cell(tier: int) -> Vector2i:
	return COMPUTERS[clampi(tier, 1, COMPUTERS.size()) - 1]


static func body_cell(staff_id: int) -> Vector2i:
	return STAFF_BODIES[absi(staff_id) % STAFF_BODIES.size()]


static func all_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key: StringName in FLOORS:
		out.append(FLOORS[key])
	out.append_array([WALL_TOP, WALL_FACE, WALL_SIDE, WALL_BOTTOM, DESK])
	out.append_array(COMPUTERS)
	out.append_array(STAFF_BODIES)
	return out


static func tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = load(SHEET_PATH) as Texture2D
	src.texture_region_size = Vector2i(TILE, TILE)
	src.margins = MARGIN
	src.separation = SEPARATION
	var cells: Array[Vector2i] = []
	for key: StringName in FLOORS:
		cells.append(FLOORS[key])
	cells.append_array([WALL_TOP, WALL_FACE, WALL_SIDE, WALL_BOTTOM])
	for cell: Vector2i in cells:
		if not src.has_tile(cell):
			src.create_tile(cell)
	ts.add_source(src, 0)
	_tileset = ts
	return ts
