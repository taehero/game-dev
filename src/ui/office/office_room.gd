class_name OfficeRoom
extends Node2D
## A room painted at runtime from size_tiles. Desk cells are tile coordinates in Floor.

const GARAGE_DESKS: Array[Vector2i] = [Vector2i(3, 3), Vector2i(7, 3)]
const SMALL_OFFICE_DESKS: Array[Vector2i] = [
	Vector2i(6, 3), Vector2i(10, 3), Vector2i(14, 3), Vector2i(6, 6), Vector2i(10, 6),
]
const GROUND_MARGIN := Vector2i(5, 3)
## Decor cell -> prop name. The cell is the prop's top-left tile.
## Plants and shelves stay right of col 4: the project card covers the top-left corner.
const DECOR: Dictionary[StringName, Dictionary] = {
	&"garage": {
		Vector2i(8, 0): &"window", Vector2i(1, 0): &"picture", Vector2i(2, 2): &"plant",
		Vector2i(5, 2): &"shelf", Vector2i(9, 2): &"barrel", Vector2i(10, 2): &"bag",
		Vector2i(4, 5): &"rug", Vector2i(10, 6): &"cone",
	},
	&"small_office": {
		Vector2i(11, 0): &"window", Vector2i(14, 0): &"window", Vector2i(1, 0): &"picture",
		Vector2i(5, 2): &"plant", Vector2i(16, 2): &"plant", Vector2i(8, 2): &"shelf",
		Vector2i(12, 6): &"rug",
	},
}

@export var size_tiles: Vector2i = Vector2i(12, 8)
@export var floor_style: StringName = &"concrete"
@export var decor_set: StringName = &""

@onready var _ground: TileMapLayer = $Ground
@onready var _floor: TileMapLayer = $Floor
@onready var _walls: TileMapLayer = $Walls
@onready var _decor: TileMapLayer = $Decor


func _ready() -> void:
	for layer: TileMapLayer in [_ground, _floor, _walls, _decor]:
		if layer.tile_set == null:
			layer.tile_set = OfficeArt.tileset()
	if _floor.get_used_cells().is_empty():
		_paint()


func is_floor(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x <= size_tiles.x - 2 and cell.y >= 2 and cell.y <= size_tiles.y - 2


func cell_to_local(cell: Vector2i) -> Vector2:
	return _floor.map_to_local(cell)


func pixel_size() -> Vector2i:
	return size_tiles * OfficeArt.TILE


func _paint() -> void:
	var w: int = size_tiles.x
	var h: int = size_tiles.y
	var floor_ref: Vector3i = OfficeArt.FLOORS.get(floor_style, OfficeArt.FLOORS[&"concrete"])
	for x: int in range(w):
		OfficeArt.paint(_walls, Vector2i(x, 0), OfficeArt.WALL_UPPER[x % 2])
		OfficeArt.paint(_walls, Vector2i(x, 1), OfficeArt.WALL_LOWER[x % 2])
		OfficeArt.paint(_walls, Vector2i(x, h - 1), OfficeArt.WALL_TOP)
	for y: int in range(2, h - 1):
		OfficeArt.paint(_walls, Vector2i(0, y), OfficeArt.WALL_TOP)
		OfficeArt.paint(_walls, Vector2i(w - 1, y), OfficeArt.WALL_TOP)
		for x: int in range(1, w - 1):
			OfficeArt.paint(_floor, Vector2i(x, y), floor_ref)
	var room_rect := Rect2i(Vector2i.ZERO, size_tiles)
	for y: int in range(-GROUND_MARGIN.y, h + GROUND_MARGIN.y):
		for x: int in range(-GROUND_MARGIN.x, w + GROUND_MARGIN.x):
			if not room_rect.has_point(Vector2i(x, y)):
				OfficeArt.paint(_ground, Vector2i(x, y), OfficeArt.GROUND)
	var props: Dictionary = DECOR.get(decor_set, {})
	for cell: Vector2i in props:
		var prop: StringName = props[cell]
		var sz: Vector2i = OfficeArt.prop_size(prop)
		for dy: int in range(sz.y):
			for dx: int in range(sz.x):
				OfficeArt.paint(_decor, cell + Vector2i(dx, dy), OfficeArt.PROPS[prop] + Vector3i(0, dx, dy))
