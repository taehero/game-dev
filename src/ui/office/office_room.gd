class_name OfficeRoom
extends Node2D
## A room painted at runtime from size_tiles. Desk cells are tile coordinates in Floor.

const GARAGE_DESKS: Array[Vector2i] = [Vector2i(3, 3), Vector2i(7, 3)]
const SMALL_OFFICE_DESKS: Array[Vector2i] = [
	Vector2i(3, 3), Vector2i(7, 3), Vector2i(11, 3), Vector2i(3, 6), Vector2i(7, 6),
]
## Backing colours: the sheet's floor and wall tiles are sparse, so solid rects sit underneath.
const FLOOR_COLORS: Dictionary[StringName, Color] = {
	&"concrete": Color("#6b6f76"),
	&"wood": Color("#8a5a35"),
}
const WALL_COLOR: Color = Color("#2b2d33")

@export var size_tiles: Vector2i = Vector2i(12, 8)
@export var floor_style: StringName = &"concrete"

@onready var _floor: TileMapLayer = $Floor
@onready var _walls: TileMapLayer = $Walls


func _ready() -> void:
	if _floor.tile_set == null:
		_floor.tile_set = OfficeArt.tileset()
	if _walls.tile_set == null:
		_walls.tile_set = OfficeArt.tileset()
	_add_backing()
	if _floor.get_used_cells().is_empty():
		_paint()


func is_floor(cell: Vector2i) -> bool:
	return cell.x >= 1 and cell.x <= size_tiles.x - 2 and cell.y >= 2 and cell.y <= size_tiles.y - 2


func cell_to_local(cell: Vector2i) -> Vector2:
	return _floor.map_to_local(cell)


func pixel_size() -> Vector2i:
	return size_tiles * OfficeArt.TILE


func _add_backing() -> void:
	var t: float = float(OfficeArt.TILE)
	var wall_back := ColorRect.new()
	wall_back.name = "WallBacking"
	wall_back.color = WALL_COLOR
	wall_back.size = Vector2(pixel_size())
	wall_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var floor_back := ColorRect.new()
	floor_back.name = "FloorBacking"
	floor_back.color = FLOOR_COLORS.get(floor_style, FLOOR_COLORS[&"concrete"])
	floor_back.position = Vector2(t, 2.0 * t)
	floor_back.size = Vector2(float(size_tiles.x - 2) * t, float(size_tiles.y - 2) * t)
	floor_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wall_back)
	add_child(floor_back)
	move_child(wall_back, 0)
	move_child(floor_back, 1)


func _paint() -> void:
	var w: int = size_tiles.x
	var h: int = size_tiles.y
	for x: int in range(w):
		_walls.set_cell(Vector2i(x, 0), 0, OfficeArt.WALL_TOP)
		_walls.set_cell(Vector2i(x, 1), 0, OfficeArt.WALL_FACE)
		_walls.set_cell(Vector2i(x, h - 1), 0, OfficeArt.WALL_BOTTOM)
	for y: int in range(2, h - 1):
		_walls.set_cell(Vector2i(0, y), 0, OfficeArt.WALL_SIDE)
		_walls.set_cell(Vector2i(w - 1, y), 0, OfficeArt.WALL_SIDE)
		for x: int in range(1, w - 1):
			_floor.set_cell(Vector2i(x, y), 0, OfficeArt.FLOORS[floor_style])
