class_name StartPromotionCommand
extends Command

var project_id: int
var discount_bp: int
var weeks: int


func _init(p_project_id: int, p_discount_bp: int, p_weeks: int) -> void:
	project_id = p_project_id
	discount_bp = p_discount_bp
	weeks = p_weeks


func validate(state: GameState, tuning: TuningDef) -> CommandResult:
	if not state.projects.has(project_id):
		return CommandResult.fail(&"error.project_not_found")
	var p: Project = state.projects[project_id]
	if p.kind != Project.Kind.GAME or p.phase != Project.Phase.LIVE:
		return CommandResult.fail(&"error.project_not_live")
	if SalesSystem.promo_active(p, state.week + 1):
		return CommandResult.fail(&"error.promo_active")
	var step: int = tuning.promo_discount_step_bp
	if discount_bp % step != 0 or discount_bp / step < 1 or discount_bp / step > tuning.promo_uplift_table_bp.size():
		return CommandResult.fail(&"error.invalid_discount")
	if weeks < 1 or weeks > tuning.promo_max_weeks:
		return CommandResult.fail(&"error.invalid_promo_weeks")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var p: Project = ctx.state.projects[project_id]
	var last: int = MarketingSystem.last_promo_end(ctx.state, p.company_id)
	if last >= 0 and ctx.state.week - last < ctx.tuning.promo_fatigue_window_weeks:
		var c: Company = ctx.state.companies[p.company_id]
		c.promo_fatigue = mini(100, c.promo_fatigue + ctx.tuning.promo_fatigue_hype)
	p.promo_discount_bp = discount_bp
	p.promo_until_week = ctx.state.week + weeks
	ctx.emit(&"promotion_started", {"project_id": project_id, "discount_bp": discount_bp, "until_week": p.promo_until_week})
