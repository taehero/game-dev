class_name HireCandidateCommand
extends Command

var company_id: int
var candidate_id: int


func _init(p_company_id: int, p_candidate_id: int) -> void:
	company_id = p_company_id
	candidate_id = p_candidate_id


func _find(state: GameState) -> Candidate:
	for c: Candidate in state.candidates:
		if c.id == candidate_id:
			return c
	return null


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	if not state.companies.has(company_id):
		return CommandResult.fail(&"error.company_not_found")
	if _find(state) == null:
		return CommandResult.fail(&"error.candidate_not_found")
	if GameRules.free_seat(state, ContentDB.active(), company_id) == -1:
		return CommandResult.fail(&"error.no_free_seat")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var c: Candidate = _find(ctx.state)
	var s := Staff.new()
	s.id = ctx.state.alloc_id()
	s.company_id = company_id
	s.name = c.name
	s.salary = c.asking_salary
	s.level = c.level as Staff.Level
	s.seat_index = GameRules.free_seat(ctx.state, ctx.content, company_id)
	s.hired_week = ctx.state.week
	s.last_raise_week = ctx.state.week
	s.set_skills(c.skills)
	ctx.state.staff[s.id] = s
	Removal.remove_candidate(ctx.state, candidate_id)
	ctx.emit(&"staff_hired", {"staff_id": s.id})
