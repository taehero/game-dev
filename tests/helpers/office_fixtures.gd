class_name OfficeFixtures
extends RefCounted
## Scene-test helpers. Not a test file.

const GARAGE_ROOM: String = "res://src/ui/office/rooms/garage_room.tscn"
const SMALL_ROOM: String = "res://src/ui/office/rooms/small_office_room.tscn"


static func garage() -> OfficeDef:
	var d := OfficeDef.new()
	d.id = &"office_garage"
	d.seats = 2
	d.desk_positions = OfficeRoom.GARAGE_DESKS.duplicate()
	d.scene_path = GARAGE_ROOM
	return d


static func small_office() -> OfficeDef:
	var d := OfficeDef.new()
	d.id = &"office_small"
	d.seats = 5
	d.desk_positions = OfficeRoom.SMALL_OFFICE_DESKS.duplicate()
	d.scene_path = SMALL_ROOM
	return d


static func offices() -> Dictionary[StringName, OfficeDef]:
	var out: Dictionary[StringName, OfficeDef] = {}
	out[&"office_garage"] = garage()
	out[&"office_small"] = small_office()
	return out


static func equipment_defs() -> Dictionary[StringName, EquipmentDef]:
	return Fixtures.content().equipment


static func set_office(state: GameState, office_id: StringName) -> void:
	state.companies[state.player_company_id].office_id = office_id
