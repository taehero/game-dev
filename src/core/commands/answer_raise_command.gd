class_name AnswerRaiseCommand
extends Command

const KINDS: Array[StringName] = [&"raise_request", &"promotion_request"]

var staff_id: int
var accept: bool


func _init(p_staff_id: int, p_accept: bool) -> void:
	staff_id = p_staff_id
	accept = p_accept


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	if not state.staff.has(staff_id):
		return CommandResult.fail(&"error.staff_not_found")
	if find_ask(state, staff_id) == null:
		return CommandResult.fail(&"error.no_raise_pending")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	resolve(ctx.state, ctx.tuning, staff_id, accept)


static func find_ask(state: GameState, p_staff_id: int) -> Decision:
	for d: Decision in state.pending_decisions:
		if KINDS.has(d.kind) and d.related_ids.has(p_staff_id):
			return d
	return null


static func resolve(state: GameState, t: TuningDef, p_staff_id: int, p_accept: bool) -> void:
	var d: Decision = find_ask(state, p_staff_id)
	var s: Staff = state.staff.get(p_staff_id)
	if d == null or s == null:
		return
	var promotion: bool = d.kind == &"promotion_request"
	if p_accept:
		s.salary = s.asking_raise
		if promotion:
			s.level = (int(s.level) + 1) as Staff.Level
	else:
		s.morale = clampi(s.morale + (t.promotion_refuse_morale if promotion else t.raise_refuse_morale), 0, 100)
		s.raise_refusals += 1
	s.asking_raise = 0
	s.last_raise_week = state.week
	Removal.remove_decision(state, d.id)
