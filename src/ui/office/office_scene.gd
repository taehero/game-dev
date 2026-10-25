class_name OfficeScene
extends Node2D
## The player's office: room, desks with computers, seated staff and work bubbles.
## Reads state only through StateQueries; content comes in through configure().

const DESK_SCENE: PackedScene = preload("res://src/ui/office/desk_sprite.tscn")
const STAFF_SCENE: PackedScene = preload("res://src/ui/office/staff_sprite.tscn")
## Slot-0 icon sits above the monitor top. Bug bubbles shift sideways of the points bubble.
const BUBBLE_OFFSET: Vector2 = Vector2(0, -34)
const BUG_BUBBLE_SHIFT: Vector2 = Vector2(12, 0)

const REFRESH_SIGNALS: Array[StringName] = [
	&"week_ticked", &"staff_hired", &"staff_resigned", &"staff_fired", &"equipment_changed",
	&"project_changed", &"project_phase_changed", &"game_loaded",
]

signal room_changed

var _offices: Dictionary[StringName, OfficeDef] = {}
var _equipment_defs: Dictionary[StringName, EquipmentDef] = {}
var _office_id: StringName = &""
var _room: OfficeRoom = null
var _desks: Array[DeskSprite] = []
var _staff: Dictionary[int, StaffSprite] = {}
var _burst_frame: int = -1
var _point_bubbles: Dictionary[int, Bubble] = {}
var _bug_bubbles: Dictionary[int, Bubble] = {}

@onready var _room_slot: Node2D = $RoomSlot
@onready var _desks_node: Node2D = $Desks
@onready var _staff_node: Node2D = $Staff
@onready var _bubbles: BubbleLayer = $Bubbles


func _ready() -> void:
	EventBus.points_gained.connect(_on_points_gained)
	EventBus.bug_found.connect(_on_bug_found)
	for sig_name: StringName in REFRESH_SIGNALS:
		Signal(EventBus, sig_name).connect(_on_refresh_event)


func _exit_tree() -> void:
	if EventBus.points_gained.is_connected(_on_points_gained):
		EventBus.points_gained.disconnect(_on_points_gained)
	if EventBus.bug_found.is_connected(_on_bug_found):
		EventBus.bug_found.disconnect(_on_bug_found)
	for sig_name: StringName in REFRESH_SIGNALS:
		var sig: Signal = Signal(EventBus, sig_name)
		if sig.is_connected(_on_refresh_event):
			sig.disconnect(_on_refresh_event)


func configure(offices: Dictionary[StringName, OfficeDef], equipment_defs: Dictionary[StringName, EquipmentDef]) -> void:
	_offices = offices
	_equipment_defs = equipment_defs
	_office_id = &""


func refresh(state: GameState, t: TuningDef) -> void:
	var office_id: StringName = StateQueries.player_office_id(state)
	if office_id != _office_id:
		_rebuild_room(office_id)
		room_changed.emit()
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


func spawn_bubble(staff_id: int, kind: StringName, amount: int = 0) -> bool:
	var sprite: StaffSprite = staff_sprite(staff_id)
	if sprite == null:
		return false
	return _bubbles.spawn(sprite.position + BUBBLE_OFFSET, kind, amount) != null


func _on_refresh_event(_payload: Dictionary) -> void:
	if GameRunner.session == null:
		return
	refresh(GameRunner.session.state, GameRunner.session.tuning)


## Events for one staff member in one frame merge into at most one points bubble and one bug bubble.
func _on_points_gained(payload: Dictionary) -> void:
	_new_frame_check()
	var sid: int = int(payload.get("staff_id", -1))
	var kind: StringName = StringName(payload.get("type", &""))
	var amount: int = int(payload.get("amount", 0))
	var existing: Bubble = _point_bubbles.get(sid, null)
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		if amount > existing.amount:
			existing.set_content(kind, amount)
		return
	var sprite: StaffSprite = staff_sprite(sid)
	if sprite == null:
		return
	var made: Bubble = _bubbles.spawn(sprite.position + BUBBLE_OFFSET, kind, amount)
	if made != null:
		_point_bubbles[sid] = made


func _on_bug_found(payload: Dictionary) -> void:
	_new_frame_check()
	var sid: int = int(payload.get("staff_id", -1))
	var existing: Bubble = _bug_bubbles.get(sid, null)
	if existing != null and is_instance_valid(existing) and not existing.is_queued_for_deletion():
		existing.set_content(&"bug", existing.amount + 1)
		return
	var sprite: StaffSprite = staff_sprite(sid)
	if sprite == null:
		return
	var made: Bubble = _bubbles.spawn(sprite.position + BUBBLE_OFFSET + BUG_BUBBLE_SHIFT, &"bug", 1)
	if made != null:
		_bug_bubbles[sid] = made


func _new_frame_check() -> void:
	var frame: int = Engine.get_process_frames()
	if frame != _burst_frame:
		_burst_frame = frame
		_point_bubbles.clear()
		_bug_bubbles.clear()


func _rebuild_room(office_id: StringName) -> void:
	_office_id = office_id
	_clear()
	if not _offices.has(office_id) or _offices[office_id].scene_path.is_empty():
		push_warning("OfficeScene: unknown office '%s'" % office_id)
		return
	var packed: PackedScene = load(_offices[office_id].scene_path) as PackedScene
	if packed == null:
		push_warning("OfficeScene: cannot load room '%s'" % _offices[office_id].scene_path)
		return
	var node: Node = packed.instantiate()
	var built: OfficeRoom = node as OfficeRoom
	if built == null:
		push_warning("OfficeScene: room '%s' is not an OfficeRoom" % _offices[office_id].scene_path)
		node.free()
		return
	_room = built
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

