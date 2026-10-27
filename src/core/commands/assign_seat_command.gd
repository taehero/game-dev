class_name AssignSeatCommand
extends Command

var staff_id: int
var seat_index: int


func _init(p_staff_id: int, p_seat_index: int) -> void:
	staff_id = p_staff_id
	seat_index = p_seat_index


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	if not state.staff.has(staff_id):
		return CommandResult.fail(&"error.staff_not_found")
	var cid: int = state.staff[staff_id].company_id
	if seat_index < -1 or seat_index >= GameRules.office_seats(state, ContentDB.active(), cid):
		return CommandResult.fail(&"error.invalid_seat")
	if seat_index >= 0:
		for sid: int in state.sorted_ids(state.staff):
			var o: Staff = state.staff[sid]
			if sid != staff_id and o.company_id == cid and o.seat_index == seat_index:
				return CommandResult.fail(&"error.seat_taken")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var st: Staff = ctx.state.staff[staff_id]
	st.seat_index = seat_index
	ctx.emit(&"equipment_changed", {"company_id": st.company_id})
