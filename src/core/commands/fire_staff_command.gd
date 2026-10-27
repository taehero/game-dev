class_name FireStaffCommand
extends Command

var staff_id: int


func _init(p_staff_id: int) -> void:
	staff_id = p_staff_id


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	if not state.staff.has(staff_id):
		return CommandResult.fail(&"error.staff_not_found")
	if state.staff[staff_id].is_owner:
		return CommandResult.fail(&"error.cannot_fire_owner")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var s: Staff = state.staff[staff_id]
	var company: Company = state.companies[s.company_id]
	company.money -= s.salary * ctx.tuning.severance_months
	Removal.remove_staff(state, staff_id)
	for id: int in state.staff_of(company.id):
		var o: Staff = state.staff[id]
		o.morale = clampi(o.morale + ctx.tuning.fire_morale_penalty, 0, 100)
	ctx.emit(&"staff_fired", {"staff_id": staff_id})
	ctx.emit(&"money_changed", {"company_id": company.id, "money": company.money})
