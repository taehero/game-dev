class_name OfficeArt
extends RefCounted
## Single source of art refs. A ref is Vector3i(sheet, column, row) in 16 px tiles.
## Sheets: Kenney Modern City, Indoors, RPG Urban, Emotes (CC0) and our own studio sheet.

const TILE: int = 16

enum Sheet { CITY, INDOOR, STUDIO, URBAN, EMOTES }

const SHEET_PATHS: Dictionary[int, String] = {
	Sheet.CITY: "res://assets/art/kenney_modern_city/tilemap_packed.png",
	Sheet.INDOOR: "res://assets/art/kenney_indoors/roguelikeIndoor_transparent.png",
	Sheet.STUDIO: "res://assets/art/studio/computers.png",
	Sheet.URBAN: "res://assets/art/kenney_urban/tilemap_packed.png",
	Sheet.EMOTES: "res://assets/art/kenney_emotes/pixel_style1.png",
}
const SEPARATIONS: Dictionary[int, Vector2i] = {
	Sheet.CITY: Vector2i(0, 0),
	Sheet.INDOOR: Vector2i(1, 1),
	Sheet.STUDIO: Vector2i(0, 0),
	Sheet.URBAN: Vector2i(0, 0),
	Sheet.EMOTES: Vector2i(0, 0),
}
## Sheets that become TileSet sources (source id == Sheet value).
const TILE_SHEETS: Array[int] = [Sheet.CITY, Sheet.INDOOR, Sheet.STUDIO]

const FLOORS: Dictionary[StringName, Vector3i] = {
	&"concrete": Vector3i(Sheet.CITY, 7, 20),
	&"wood": Vector3i(Sheet.STUDIO, 0, 1),
	&"carpet": Vector3i(Sheet.STUDIO, 1, 1),
}
const GROUND: Vector3i = Vector3i(Sheet.CITY, 1, 24)
const WALL_UPPER: Array[Vector3i] = [Vector3i(Sheet.CITY, 9, 6), Vector3i(Sheet.CITY, 10, 6)]
const WALL_LOWER: Array[Vector3i] = [Vector3i(Sheet.CITY, 9, 8), Vector3i(Sheet.CITY, 10, 8)]
const WALL_TOP: Vector3i = Vector3i(Sheet.STUDIO, 2, 1)

const DESK_LEFT: Vector3i = Vector3i(Sheet.INDOOR, 4, 4)
const DESK_RIGHT: Vector3i = Vector3i(Sheet.INDOOR, 6, 4)
const CHAIR: Vector3i = Vector3i(Sheet.INDOOR, 1, 2)
const CHAIR_CLIP_TOP: int = 6
## Index 0 = tier 1.
const COMPUTERS: Array[Vector3i] = [
	Vector3i(Sheet.STUDIO, 0, 0), Vector3i(Sheet.STUDIO, 1, 0), Vector3i(Sheet.STUDIO, 2, 0),
]
const STAFF_BACKS: Array[Vector3i] = [
	Vector3i(Sheet.URBAN, 25, 0), Vector3i(Sheet.URBAN, 25, 3), Vector3i(Sheet.URBAN, 25, 6),
	Vector3i(Sheet.URBAN, 25, 12), Vector3i(Sheet.URBAN, 25, 15),
]
## The ref is the top-left tile of the prop.
const PROPS: Dictionary[StringName, Vector3i] = {
	&"plant": Vector3i(Sheet.INDOOR, 16, 0),
	&"shelf": Vector3i(Sheet.INDOOR, 20, 17),
	&"rug": Vector3i(Sheet.INDOOR, 23, 0),
	&"picture": Vector3i(Sheet.INDOOR, 20, 12),
	&"window": Vector3i(Sheet.CITY, 13, 6),
	&"bag": Vector3i(Sheet.CITY, 13, 13),
	&"barrel": Vector3i(Sheet.CITY, 12, 14),
	&"cone": Vector3i(Sheet.CITY, 14, 18),
}
## Footprint in tiles; a missing prop is 1x1.
const PROP_SIZES: Dictionary[StringName, Vector2i] = {
	&"shelf": Vector2i(2, 1),
	&"rug": Vector2i(3, 2),
	&"picture": Vector2i(2, 1),
	&"window": Vector2i(3, 2),
}
const EMOTES: Dictionary[StringName, Vector3i] = {
	&"design": Vector3i(Sheet.EMOTES, 7, 2),
	&"tech": Vector3i(Sheet.EMOTES, 3, 0),
	&"art": Vector3i(Sheet.EMOTES, 7, 1),
	&"audio": Vector3i(Sheet.EMOTES, 9, 1),
	&"bug": Vector3i(Sheet.EMOTES, 2, 2),
}

static var _tileset: TileSet = null
static var _textures: Dictionary[int, Texture2D] = {}


static func region(ref: Vector3i) -> Rect2i:
	return Rect2i(Vector2i(ref.y, ref.z) * (Vector2i(TILE, TILE) + SEPARATIONS[ref.x]), Vector2i(TILE, TILE))


static func _texture(sheet: int) -> Texture2D:
	if not _textures.has(sheet):
		_textures[sheet] = load(SHEET_PATHS[sheet]) as Texture2D
	return _textures[sheet]


static func atlas(ref: Vector3i) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = _texture(ref.x)
	tex.region = Rect2(region(ref))
	return tex


static func chair_overlay() -> AtlasTexture:
	var tex := atlas(CHAIR)
	tex.region = tex.region.grow_individual(0, -CHAIR_CLIP_TOP, 0, 0)
	return tex


static func computer_ref(tier: int) -> Vector3i:
	return COMPUTERS[clampi(tier, 1, COMPUTERS.size()) - 1]


static func body_ref(staff_id: int) -> Vector3i:
	return STAFF_BACKS[absi(staff_id) % STAFF_BACKS.size()]


static func prop_size(prop: StringName) -> Vector2i:
	return PROP_SIZES.get(prop, Vector2i.ONE)


static func all_refs() -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	out.append_array(FLOORS.values())
	out.append(GROUND)
	out.append_array(WALL_UPPER)
	out.append_array(WALL_LOWER)
	out.append_array([WALL_TOP, DESK_LEFT, DESK_RIGHT, CHAIR])
	out.append_array(COMPUTERS)
	out.append_array(STAFF_BACKS)
	for prop: StringName in PROPS:
		var sz: Vector2i = prop_size(prop)
		for dy: int in range(sz.y):
			for dx: int in range(sz.x):
				out.append(PROPS[prop] + Vector3i(0, dx, dy))
	out.append_array(EMOTES.values())
	return out


static func tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	for sheet: int in TILE_SHEETS:
		var src := TileSetAtlasSource.new()
		src.texture = _texture(sheet)
		src.texture_region_size = Vector2i(TILE, TILE)
		src.separation = SEPARATIONS[sheet]
		ts.add_source(src, sheet)
	for ref: Vector3i in all_refs():
		if ref.x in TILE_SHEETS:
			var src := ts.get_source(ref.x) as TileSetAtlasSource
			var coords := Vector2i(ref.y, ref.z)
			if not src.has_tile(coords):
				src.create_tile(coords)
	_tileset = ts
	return ts


static func paint(layer: TileMapLayer, at: Vector2i, ref: Vector3i) -> void:
	layer.set_cell(at, ref.x, Vector2i(ref.y, ref.z))
