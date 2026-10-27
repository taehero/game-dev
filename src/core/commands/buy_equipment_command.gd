class_name BuyEquipmentCommand
extends Command

var company_id: int
var def_id: StringName
var seat_index: int
var _leased: bool = false


func _init(p_company_id: int, p_def_id: StringName, p_seat_index: int) -> void:
	company_id = p_company_id
	def_id = p_def_id
	seat_index = p_seat_index


func validate(state: GameState, tuning: TuningDef) -> CommandResult:
	if not state.companies.has(company_id):
		return CommandResult.fail(&"error.company_not_found")
	var content: ContentDB = ContentDB.active()
	if not content.equipment.has(def_id):
		return CommandResult.fail(&"error.equipment_not_found")
	var def: EquipmentDef = content.equipment[def_id]
	if Calendar.year(state.week, tuning) < def.year_from:
		return CommandResult.fail(&"error.equipment_not_available")
	if seat_index < 0 or seat_index >= GameRules.office_seats(state, content, company_id):
		return CommandResult.fail(&"error.invalid_seat")
	if GameRules.equipment_at_seat(state, company_id, seat_index) != -1:
		return CommandResult.fail(&"error.seat_has_equipment")
	if not _leased and state.companies[company_id].money < def.price:
		return CommandResult.fail(&"error.not_enough_money")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var company: Company = ctx.state.companies[company_id]
	var e := Equipment.new()
	e.id = ctx.state.alloc_id()
	e.company_id = company_id
	e.def_id = def_id
	e.seat_index = seat_index
	e.bought_week = ctx.state.week
	if _leased:
		e.ownership = Equipment.Ownership.LEASED
	else:
		var price: int = ctx.content.equipment[def_id].price
		e.value = price
		company.money -= price
	ctx.state.equipment[e.id] = e
	ctx.emit(&"equipment_changed", {"equipment_id": e.id})
	if not _leased:
		ctx.emit(&"money_changed", {"company_id": company_id, "money": company.money})
