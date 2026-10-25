class_name PlaceEquipmentCommand
extends Command
## Test-only stand-in for M2b's BuyEquipment: puts a BOUGHT Equipment at a seat.

var company_id: int
var def_id: StringName
var seat: int


func _init(p_company_id: int, p_def_id: StringName, p_seat: int) -> void:
	company_id = p_company_id
	def_id = p_def_id
	seat = p_seat


func apply(ctx: TickContext) -> void:
	var e := Equipment.new()
	e.id = ctx.state.alloc_id()
	e.company_id = company_id
	e.def_id = def_id
	e.ownership = Equipment.Ownership.BOUGHT
	e.seat_index = seat
	e.bought_week = ctx.state.week
	ctx.state.equipment[e.id] = e
	ctx.emit(&"equipment_changed", {"equipment_id": e.id})
