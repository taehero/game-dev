class_name ContractsSystem
extends RefCounted
## M2 spec 5 step 9: contract-work settlement, offer expiry and monthly offers.


static func tick(ctx: TickContext) -> void:
	_settle(ctx)
	_expire(ctx)
	if Calendar.is_month_start(ctx.state.week, ctx.tuning):
		for i: int in ctx.tuning.contract_offers_per_month:
			_offer(ctx)


static func _settle(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	for pid: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[pid]
		if p.kind != Project.Kind.CONTRACT_WORK or p.phase != Project.Phase.PRODUCTION:
			continue
		if not state.contracts.has(p.contract_id):
			continue
		var c: Contract = state.contracts[p.contract_id]
		var met: bool = true
		for type: StringName in GameState.sorted_names(c.target_points):
			if int(p.points.get(type, 0)) < c.target_points[type]:
				met = false
		var company: Company = state.companies[p.company_id]
		var paid: int = c.price
		if not met:
			if state.week < c.deadline_week:
				continue
			paid = Fixed.mul_bp(c.price, ctx.tuning.contract_miss_pay_bp)
			company.reputation = clampi(company.reputation + ctx.tuning.contract_miss_reputation, 0, 100)
		company.money += paid
		p.phase = Project.Phase.RETIRED
		p.revenue = paid
		for sid: int in state.sorted_ids(state.staff):
			if state.staff[sid].assigned_project_id == pid:
				state.staff[sid].assigned_project_id = -1
		ctx.emit(&"contract_completed", {"contract_id": c.id, "paid": paid, "met": met})
		ctx.emit(&"money_changed", {"company_id": company.id, "money": company.money})
		ctx.emit(&"project_phase_changed", {"project_id": pid, "phase": "RETIRED"})


static func _expire(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var gone: Array[int] = []
	for cid: int in state.sorted_ids(state.contracts):
		var c: Contract = state.contracts[cid]
		if c.kind == Contract.Kind.CONTRACT_WORK and c.project_id == -1 and state.week >= c.delivery_week:
			gone.append(cid)
	for cid: int in gone:
		Removal.remove_contract(state, cid)


static func _offer(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var t: TuningDef = ctx.tuning
	var pubs: Array[int] = []
	for id: int in state.sorted_ids(state.companies):
		if state.companies[id].kind == Company.Kind.AI_PUBLISHER:
			pubs.append(id)
	if pubs.is_empty():
		return
	var c := Contract.new()
	c.id = state.alloc_id()
	c.kind = Contract.Kind.CONTRACT_WORK
	c.party_a = state.player_company_id
	c.party_b = pubs[ctx.rng.randi_range(0, pubs.size() - 1)]
	var total: int = 0
	for type: StringName in GameRules.SKILL_ORDER:
		var pts: int = ctx.rng.randi_range(t.contract_points_min, t.contract_points_max)
		c.target_points[type] = pts
		total += pts
	c.deadline_week = state.week + ctx.rng.randi_range(t.contract_weeks_min, t.contract_weeks_max)
	c.delivery_week = state.week + t.contract_offer_weeks
	c.price = Fixed.mul_bp(total * t.contract_pay_per_point,
		Fixed.ONE_BP + PeopleRules.effect_bp(state, ctx.content, &"contract_pay_bp"))
	state.contracts[c.id] = c
	ctx.emit(&"contract_offered", {"contract_id": c.id})
