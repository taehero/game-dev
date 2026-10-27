class_name MoveOfficeCommand
extends Command

var company_id: int
var office_id: StringName


func _init(p_company_id: int, p_office_id: StringName) -> void:
	company_id = p_company_id
	office_id = p_office_id


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	if not state.companies.has(company_id):
		return CommandResult.fail(&"error.company_not_found")
	var content: ContentDB = ContentDB.active()
	if not content.offices.has(office_id):
		return CommandResult.fail(&"error.office_not_found")
	var company: Company = state.companies[company_id]
	if company.office_id == office_id:
		return CommandResult.fail(&"error.office_current")
	var def: OfficeDef = content.offices[office_id]
	if company.money < def.moving_cost:
		return CommandResult.fail(&"error.not_enough_money")
	for sid: int in state.staff_of(company_id):
		if state.staff[sid].seat_index >= def.seats:
			return CommandResult.fail(&"error.office_too_small")
	for eid: int in state.sorted_ids(state.equipment):
		var e: Equipment = state.equipment[eid]
		if e.company_id == company_id and e.seat_index >= def.seats:
			return CommandResult.fail(&"error.office_too_small")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var company: Company = ctx.state.companies[company_id]
	company.money -= ctx.content.offices[office_id].moving_cost
	company.office_id = office_id
	ctx.emit(&"equipment_changed", {"company_id": company_id, "office_id": office_id})
	ctx.emit(&"money_changed", {"company_id": company_id, "money": company.money})
