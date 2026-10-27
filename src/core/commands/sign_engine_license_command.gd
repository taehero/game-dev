class_name SignEngineLicenseCommand
extends Command

var company_id: int
var licensed_id: StringName


func _init(p_company_id: int, p_licensed_id: StringName) -> void:
	company_id = p_company_id
	licensed_id = p_licensed_id


func validate(state: GameState, tuning: TuningDef) -> CommandResult:
	if not state.companies.has(company_id):
		return CommandResult.fail(&"error.company_not_found")
	var content: ContentDB = ContentDB.active()
	if not content.licensed_engines.has(licensed_id):
		return CommandResult.fail(&"error.engine_unavailable")
	var def: LicensedEngineDef = content.licensed_engines[licensed_id]
	var year: int = Calendar.year(state.week, tuning)
	if year < def.year_from or year > def.year_to:
		return CommandResult.fail(&"error.engine_unavailable")
	if def.fee <= 0:
		return CommandResult.fail(&"error.license_not_needed")
	if GameRules.engine_license_contract(state, company_id, licensed_id) != null:
		return CommandResult.fail(&"error.license_owned")
	if state.companies[company_id].money < def.fee:
		return CommandResult.fail(&"error.not_enough_money")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var def: LicensedEngineDef = ctx.content.licensed_engines[licensed_id]
	var c := Contract.new()
	c.id = ctx.state.alloc_id()
	c.kind = Contract.Kind.ENGINE_LICENSE
	c.party_a = company_id
	c.party_b = GameRules.first_vendor(ctx.state)
	c.price = def.fee
	c.royalty_bp = def.royalty_bp
	c.deliverable = licensed_id
	ctx.state.contracts[c.id] = c
	var company: Company = ctx.state.companies[company_id]
	company.money -= def.fee
	ctx.emit(&"money_changed", {"company_id": company_id, "money": company.money})
