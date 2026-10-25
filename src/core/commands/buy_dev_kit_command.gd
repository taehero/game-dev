class_name BuyDevKitCommand
extends Command

var company_id: int
var platform_id: StringName


func _init(p_company_id: int, p_platform_id: StringName) -> void:
	company_id = p_company_id
	platform_id = p_platform_id


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	if not state.companies.has(company_id):
		return CommandResult.fail(&"error.company_not_found")
	var content: ContentDB = ContentDB.active()
	if not content.platforms.has(platform_id):
		return CommandResult.fail(&"error.platform_not_found")
	var def: PlatformDef = content.platforms[platform_id]
	if GameRules.platform_status(def, state.week) != GameRules.PlatformStatus.ON_SALE:
		return CommandResult.fail(&"error.platform_not_on_sale")
	if GameRules.has_dev_kit(state, content, company_id, platform_id):
		return CommandResult.fail(&"error.dev_kit_owned")
	if state.companies[company_id].money < def.dev_kit_cost:
		return CommandResult.fail(&"error.not_enough_money")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var company: Company = ctx.state.companies[company_id]
	company.money -= ctx.content.platforms[platform_id].dev_kit_cost
	company.dev_kits.append(platform_id)
	ctx.emit(&"money_changed", {"company_id": company_id, "money": company.money})
