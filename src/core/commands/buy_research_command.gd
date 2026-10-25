class_name BuyResearchCommand
extends Command

var company_id: int
var research_id: StringName


func _init(p_company_id: int, p_research_id: StringName) -> void:
	company_id = p_company_id
	research_id = p_research_id


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	if not state.companies.has(company_id):
		return CommandResult.fail(&"error.company_not_found")
	var content: ContentDB = ContentDB.active()
	if not content.research.has(research_id):
		return CommandResult.fail(&"error.research_not_found")
	var company: Company = state.companies[company_id]
	if company.unlocked.has(research_id):
		return CommandResult.fail(&"error.research_done")
	var def: ResearchDef = content.research[research_id]
	for pre: StringName in def.prerequisites:
		if not company.unlocked.has(pre):
			return CommandResult.fail(&"error.research_locked")
	if company.research_points < def.cost_rp:
		return CommandResult.fail(&"error.not_enough_rp")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var company: Company = ctx.state.companies[company_id]
	company.research_points -= ctx.content.research[research_id].cost_rp
	company.unlocked.append(research_id)
	ctx.emit(&"research_done", {"company_id": company_id, "research_id": research_id})
