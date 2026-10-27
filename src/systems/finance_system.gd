class_name FinanceSystem
extends RefCounted


static func tick(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	if not Calendar.is_month_start(state.week, ctx.tuning):
		return
	for company_id: int in state.sorted_ids(state.companies):
		var company: Company = state.companies[company_id]
		if company.kind != Company.Kind.PLAYER:
			continue
		var start_money: int = company.money
		_upgrade_leases(ctx, company_id)
		company.money -= int(MoneyRules.monthly_costs(state, ctx.content, company_id)["total"])
		for eid: int in state.sorted_ids(state.equipment):
			var e: Equipment = state.equipment[eid]
			if e.company_id == company_id and e.ownership == Equipment.Ownership.BOUGHT:
				e.value = Fixed.mul_bp(e.value, Fixed.ONE_BP - ctx.tuning.depreciation_bp_per_month)
		# T10 loans, T11 bankruptcy slot in here.
		if company.money != start_money:
			ctx.emit(&"money_changed", {"company_id": company_id, "money": company.money})


static func _upgrade_leases(ctx: TickContext, company_id: int) -> void:
	var state: GameState = ctx.state
	var year: int = Calendar.year(state.week, ctx.tuning)
	var best_id: StringName = &""
	var best_tier: int = -1
	for name: StringName in GameState.sorted_names(ctx.content.equipment):
		var def: EquipmentDef = ctx.content.equipment[name]
		if year >= def.year_from and def.tier > best_tier:
			best_tier = def.tier
			best_id = name
	for eid: int in state.sorted_ids(state.equipment):
		var e: Equipment = state.equipment[eid]
		if e.company_id != company_id or e.ownership != Equipment.Ownership.LEASED:
			continue
		if ctx.content.equipment.has(e.def_id) and best_tier > ctx.content.equipment[e.def_id].tier:
			e.def_id = best_id
			ctx.emit(&"equipment_changed", {"company_id": company_id, "office_id": ctx.state.companies[company_id].office_id})
