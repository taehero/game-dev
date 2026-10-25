class_name OfficeScene
extends Node2D
## The player's office: room, desks with computers, seated staff and work bubbles.
## Reads state only through StateQueries; content comes in through configure().

const DESK_SCENE: PackedScene = preload("res://src/ui/office/desk_sprite.tscn")
const STAFF_SCENE: PackedScene = preload("res://src/ui/office/staff_sprite.tscn")
const BUBBLE_OFFSET: Vector2 = Vector2(0, -12)

var _offices: Dictionary[StringName, OfficeDef] = {}
var _equipment_defs: Dictionary[StringName, EquipmentDef] = {}
var _office_id: StringName = &""
var _room: OfficeRoom = null
var _desks: Array[DeskSprite] = []
var _staff: Dictionary[int, StaffSprite] = {}

@onready var _room_slot: Node2D = $RoomSlot
@onready var _desks_node: Node2D = $Desks
@onready var _staff_node: Node2D = $Staff
@onready var _bubbles: BubbleLayer = $Bubbles


func configure(offices: Dictionary[StringName, OfficeDef], equipment_defs: Dictionary[StringName, EquipmentDef]) -> void:
	_offices = offices
	_equipment_defs = equipment_defs


func refresh(state: GameState, t: TuningDef) -> void:
	var office_id: StringName = StateQueries.player_office_id(state)
	if office_id != _office_id or (_room == null and _offices.has(office_id)):
		_rebuild_room(office_id)
	if _room == null:
		return
	var views: Array[SeatView] = StateQueries.seat_views(state, _offices[office_id], _equipment_defs, t)
	_reconcile_desks(views)
	_reconcile_staff(views)


func room() -> OfficeRoom:
	return _room


func desk_count() -> int:
	return _desks.size()


func desk_at(seat_index: int) -> DeskSprite:
	if seat_index < 0 or seat_index >= _desks.size():
		return null
	return _desks[seat_index]


func staff_sprite(staff_id: int) -> StaffSprite:
	return _staff.get(staff_id, null)


func spawn_bubble(staff_id: int, kind: StringName) -> bool:
	var sprite: StaffSprite = staff_sprite(staff_id)
	if sprite == null:
		return false
	return _bubbles.spawn(sprite.position + BUBBLE_OFFSET, kind) != null


func _rebuild_room(office_id: StringName) -> void:
	_office_id = office_id
	_clear()
	if not _offices.has(office_id):
		push_warning("OfficeScene: unknown office '%s'" % office_id)
		return
	var packed: PackedScene = load(_offices[office_id].scene_path) as PackedScene
	if packed == null:
		push_warning("OfficeScene: cannot load room '%s'" % _offices[office_id].scene_path)
		return
	_room = packed.instantiate() as OfficeRoom
	_room_slot.add_child(_room)


func _clear() -> void:
	for sprite: StaffSprite in _staff.values():
		sprite.queue_free()
		_staff_node.remove_child(sprite)
	_staff.clear()
	for desk: DeskSprite in _desks:
		desk.queue_free()
		_desks_node.remove_child(desk)
	_desks.clear()
	if _room != null:
		_room.queue_free()
		_room_slot.remove_child(_room)
		_room = null


func _reconcile_desks(views: Array[SeatView]) -> void:
	while _desks.size() > views.size():
		var extra: DeskSprite = _desks.pop_back()
		_desks_node.remove_child(extra)
		extra.queue_free()
	while _desks.size() < views.size():
		var desk: DeskSprite = DESK_SCENE.instantiate() as DeskSprite
		_desks_node.add_child(desk)
		_desks.append(desk)
	for i: int in views.size():
		_desks[i].position = _room.cell_to_local(views[i].desk_cell)
		_desks[i].set_computer_tier(views[i].computer_tier)


func _reconcile_staff(views: Array[SeatView]) -> void:
	var shown: Dictionary[int, bool] = {}
	for view: SeatView in views:
		if view.staff_id == -1:
			continue
		shown[view.staff_id] = true
		var sprite: StaffSprite = _staff.get(view.staff_id, null)
		if sprite == null:
			sprite = STAFF_SCENE.instantiate() as StaffSprite
			_staff_node.add_child(sprite)
			sprite.set_look(view.staff_id)
			_staff[view.staff_id] = sprite
		sprite.position = _room.cell_to_local(view.desk_cell + Vector2i(0, 1))
		if sprite.pose != view.pose:
			sprite.set_pose(view.pose)
	for sid: int in _staff.keys():
		if not shown.has(sid):
			var gone: StaffSprite = _staff[sid]
			_staff.erase(sid)
			_staff_node.remove_child(gone)
			gone.queue_free()

