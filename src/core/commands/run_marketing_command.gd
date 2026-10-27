class_name RunMarketingCommand
extends Command

var project_id: int
var channel_id: StringName


func _init(p_project_id: int, p_channel_id: StringName) -> void:
	project_id = p_project_id
	channel_id = p_channel_id


func validate(state: GameState, tuning: TuningDef) -> CommandResult:
	if not state.projects.has(project_id):
		return CommandResult.fail(&"error.project_not_found")
	var p: Project = state.projects[project_id]
	if p.kind != Project.Kind.GAME or (p.phase != Project.Phase.PRODUCTION and p.phase != Project.Phase.POLISH):
		return CommandResult.fail(&"error.project_not_marketable")
	var content: ContentDB = ContentDB.active()
	var block: StringName = MarketingSystem.channel_block_key(state, content, tuning, p.company_id, channel_id)
	if block != &"":
		return CommandResult.fail(block)
	if state.companies[p.company_id].money < content.channels[channel_id].cost:
		return CommandResult.fail(&"error.not_enough_money")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var p: Project = ctx.state.projects[project_id]
	var c: Company = ctx.state.companies[p.company_id]
	var def: MarketingChannelDef = ctx.content.channels[channel_id]
	c.money -= def.cost
	p.hype = mini(100, p.hype + MarketingSystem.hype_gain(ctx.state, ctx.content, def))
	ctx.emit(&"money_changed", {"company_id": c.id, "money": c.money})
	ctx.emit(&"project_changed", {"project_id": project_id})
