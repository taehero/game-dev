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
	if state.staff_of(company_id).size() >= tuning.max_staff_default:
		return CommandResult.fail(&"error.staff_limit")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var s := Staff.new()
	s.id = ctx.state.alloc_id()
	s.company_id = company_id
	s.name = staff_name
	s.salary = salary
	for skill: StringName in [&"design", &"tech", &"art", &"audio"]:
		s.skills[skill] = ctx.rng.randi_range(ctx.tuning.hire_skill_min, ctx.tuning.hire_skill_max)
	ctx.state.staff[s.id] = s
	ctx.emit(&"staff_hired", {"staff_id": s.id})
