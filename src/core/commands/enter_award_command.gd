class_name EnterAwardCommand
extends Command

var project_id: int
var award_id: StringName


func _init(p_project_id: int, p_award_id: StringName) -> void:
	project_id = p_project_id
	award_id = p_award_id


func validate(state: GameState, tuning: TuningDef) -> CommandResult:
	var content: ContentDB = ContentDB.active()
	if not content.awards.has(award_id):
		return CommandResult.fail(&"error.award_not_found")
	if not state.projects.has(project_id):
		return CommandResult.fail(&"error.project_not_found")
	var p: Project = state.projects[project_id]
	var def: AwardDef = content.awards[award_id]
	if p.award_entry != &"":
		return CommandResult.fail(&"error.award_entered")
	if not AwardsSystem.eligible(p, AwardsSystem.next_ceremony_week(def, state.week, tuning), tuning):
		return CommandResult.fail(&"error.award_not_eligible")
	if state.companies[p.company_id].money < def.entry_fee:
		return CommandResult.fail(&"error.not_enough_money")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var p: Project = ctx.state.projects[project_id]
	var c: Company = ctx.state.companies[p.company_id]
	c.money -= ctx.content.awards[award_id].entry_fee
	p.award_entry = award_id
	ctx.emit(&"money_changed", {"company_id": c.id, "money": c.money})
	ctx.emit(&"project_changed", {"project_id": project_id})
