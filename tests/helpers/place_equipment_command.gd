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


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	var content: ContentDB = ContentDB.active()
	if not content.equipment.has(def_id):
		return CommandResult.fail(&"error.research_not_found")
	if seat < 0 or seat >= GameRules.office_seats(state, content, company_id):
		return CommandResult.fail(&"error.no_free_seat")
	if GameRules.equipment_at_seat(state, company_id, seat) != -1:
		return CommandResult.fail(&"error.no_free_seat")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var e := Equipment.new()
	e.id = ctx.state.alloc_id()
	e.company_id = company_id
	e.def_id = def_id
	e.ownership = Equipment.Ownership.BOUGHT
	e.seat_index = seat
	e.value = ctx.content.equipment[def_id].price
	e.bought_week = ctx.state.week
	ctx.state.equipment[e.id] = e
	ctx.emit(&"equipment_changed", {"equipment_id": e.id})
