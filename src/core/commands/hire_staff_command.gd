class_name HireStaffCommand
extends Command

var company_id: int
var staff_name: String
var salary: int


func _init(p_company_id: int, p_name: String, p_salary: int) -> void:
	company_id = p_company_id
	staff_name = p_name
	salary = p_salary


func validate(state: GameState, tuning: TuningDef) -> CommandResult:
	if not state.companies.has(company_id):
		return CommandResult.fail(&"error.company_not_found")
	if salary <= 0:
		return CommandResult.fail(&"error.invalid_salary")
	if GameRules.free_seat(state, ContentDB.active(), company_id) == -1:
		return CommandResult.fail(&"error.no_free_seat")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var s := Staff.new()
	s.id = ctx.state.alloc_id()
	s.company_id = company_id
	s.name = staff_name
	s.salary = salary
	s.seat_index = GameRules.free_seat(ctx.state, ctx.content, company_id)
	s.hired_week = ctx.state.week
	s.last_raise_week = ctx.state.week
	s.level = Staff.Level.JUNIOR
	# Draw order is fixed (GameRules.SKILL_ORDER); set_skills inserts sorted (Ruling 14).
	var drawn: Dictionary[StringName, int] = {}
	for skill: StringName in GameRules.SKILL_ORDER:
		drawn[skill] = ctx.rng.randi_range(ctx.tuning.hire_skill_min, ctx.tuning.hire_skill_max)
	s.set_skills(drawn)
	ctx.state.staff[s.id] = s
	ctx.emit(&"staff_hired", {"staff_id": s.id})
