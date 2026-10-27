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
		_loans(ctx, company)
		_seize(ctx, company)
		_bankruptcy(ctx, company)
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


## B13: interest accrues, then every loan is paid (even into the negative) unless money is below 0.
static func _loans(ctx: TickContext, company: Company) -> void:
	var state: GameState = ctx.state
	var missed: bool = company.money < 0
	for lid: int in state.sorted_ids(state.loans):
		var l: Loan = state.loans[lid]
		if l.company_id != company.id:
			continue
		var interest: int = Fixed.mul_bp(l.balance, l.rate_bp_per_month)
		l.balance += interest
		var due: int = mini(l.balance, l.payment_per_month + interest)
		if missed:
			l.missed_payments += 1
			company.last_missed_week = state.week
			ctx.emit(&"payment_missed", {"loan_id": lid, "amount": due})
			if state.companies[l.lender_id].kind == Company.Kind.LENDER:
				_repossess(ctx, company, l, due)
			continue
		company.money -= due
		l.balance -= due
		if l.missed_payments < ctx.tuning.shark_seize_after_missed:
			l.missed_payments = 0
		if l.balance <= 0:
			Removal.remove_loan(state, lid)


## Spec 7.7: the lender takes the oldest BOUGHT equipment until it covers the missed payment x 150%.
static func _repossess(ctx: TickContext, company: Company, l: Loan, due: int) -> void:
	var state: GameState = ctx.state
	var order: Array[Vector2i] = []
	for eid: int in state.sorted_ids(state.equipment):
		var e: Equipment = state.equipment[eid]
		if e.company_id == company.id and e.ownership == Equipment.Ownership.BOUGHT:
			order.append(Vector2i(e.bought_week, eid))
	order.sort()
	var target: int = Fixed.mul_bp(due, ctx.tuning.shark_repossess_bp)
	var taken: Array[int] = []
	var value: int = 0
	for key: Vector2i in order:
		if value >= target:
			break
		value += state.equipment[key.y].value
		taken.append(key.y)
		Removal.remove_equipment(state, key.y)
	if not taken.is_empty():
		l.balance -= mini(l.balance, due)
		ctx.emit(&"equipment_changed", {"company_id": company.id, "office_id": company.office_id})
		ctx.emit(&"repossessed", {"loan_id": l.id, "equipment_ids": taken, "value": value})
	company.reputation = clampi(company.reputation + ctx.tuning.repossess_reputation, 0, 100)
	for sid: int in state.staff_of(company.id):
		var m: Staff = state.staff[sid]
		m.morale = clampi(m.morale + ctx.tuning.repossess_morale, 0, 100)


## Three misses in a row: the shark also takes a share of cash each month until repaid.
static func _seize(ctx: TickContext, company: Company) -> void:
	var state: GameState = ctx.state
	for lid: int in state.sorted_ids(state.loans):
		var l: Loan = state.loans[lid]
		if l.company_id != company.id or state.companies[l.lender_id].kind != Company.Kind.LENDER:
			continue
		if l.missed_payments < ctx.tuning.shark_seize_after_missed or company.money <= 0:
			continue
		var seized: int = mini(l.balance, Fixed.mul_bp(company.money, ctx.tuning.shark_seize_bp))
		company.money -= seized
		l.balance -= seized
		if l.balance <= 0:
			Removal.remove_loan(state, lid)


static func _bankruptcy(ctx: TickContext, company: Company) -> void:
	if company.money < 0:
		company.months_negative += 1
	else:
		company.months_negative = 0
	if company.months_negative >= ctx.tuning.bankrupt_months and not MoneyRules.has_credit(ctx.state, company.id, ctx.tuning):
		ctx.state.game_over = true
		ctx.emit(&"game_over", {"company_id": company.id})
