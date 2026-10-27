class_name SalesSystem
extends RefCounted
## Spec 6.6-6.7, Rulings A14 and A17. Weekly units, revenue split and retirement. No RNG.


## Table lookup: one entry per 10 points of score or hype, clamped at both ends.
@warning_ignore("integer_division")
static func table_bp(table: Array[int], score_or_hype: int) -> int:
	if table.is_empty():
		return 0
	return table[clampi(score_or_hype / 10, 0, table.size() - 1)]


static func launch_units(state: GameState, content: ContentDB, t: TuningDef, p: Project) -> int:
	var platform_id: StringName = p.config.get(&"platform", &"")
	var units: int = state.market.platform_install_base.get(platform_id, 0)
	var fatigue: int = state.companies[p.company_id].promo_fatigue if state.companies.has(p.company_id) else 0
	var fit: int = Fixed.ONE_BP
	var topic_id: StringName = p.config.get(&"topic", &"")
	var genre_id: StringName = p.config.get(&"genre", &"")
	if content.topics.has(topic_id):
		fit = content.topics[topic_id].genre_fit_bp.get(genre_id, Fixed.ONE_BP)
	units = Fixed.mul_bp(units, fit)
	units = Fixed.mul_bp(units, content.sizes[p.size_id].audience_bp)
	units = Fixed.mul_bp(units, table_bp(t.sales_hype_table_bp, maxi(0, p.hype - fatigue)))
	units = Fixed.mul_bp(units, table_bp(t.sales_review_table_bp, p.user_score))
	return units


static func decay_bp(content: ContentDB, t: TuningDef, p: Project, week: int) -> int:
	var d: int = table_bp(t.sales_decay_table_bp, p.user_score)
	if p.mod_tools:
		d += t.mod_tail_bp
	d += clampi(p.sentiment, -100, 100) * t.sentiment_decay_bp_per_point
	d = clampi(d, 0, t.sales_decay_max_bp)
	var platform_id: StringName = p.config.get(&"platform", &"")
	if content.platforms.has(platform_id):
		if GameRules.platform_status(content.platforms[platform_id], week) == GameRules.PlatformStatus.RETIRED:
			return maxi(0, 2 * d - Fixed.ONE_BP)
	return d


static func royalty_bp(state: GameState, content: ContentDB, p: Project) -> int:
	if state.engines.has(p.engine_id):
		return 0
	var licensed_id: StringName = p.config.get(&"engine", &"")
	var c: Contract = GameRules.engine_license_contract(state, p.company_id, licensed_id)
	if c != null:
		return c.royalty_bp
	if content.licensed_engines.has(licensed_id):
		return content.licensed_engines[licensed_id].royalty_bp
	return 0


static func promo_active(p: Project, week: int) -> bool:
	return p.promo_discount_bp > 0 and week <= p.promo_until_week


@warning_ignore("integer_division")
static func promo_uplift_bp(t: TuningDef, discount_bp: int) -> int:
	return t.promo_uplift_table_bp[clampi(discount_bp / t.promo_discount_step_bp - 1, 0, t.promo_uplift_table_bp.size() - 1)]


static func unit_price(content: ContentDB, p: Project, week: int) -> int:
	var price: int = content.sizes[p.size_id].price
	if promo_active(p, week):
		return Fixed.mul_bp(price, Fixed.ONE_BP - p.promo_discount_bp)
	return price


## Books one sale: publisher share, royalty, project revenue and company money. Returns net.
static func book_sale(ctx: TickContext, p: Project, units: int, price: int) -> int:
	var state: GameState = ctx.state
	p.units_sold += units
	var gross: int = units * price
	var pub: int = 0
	if p.contract_id != -1 and state.contracts.has(p.contract_id):
		var c: Contract = state.contracts[p.contract_id]
		if c.kind == Contract.Kind.PUBLISHING:
			pub = gross * c.revenue_share_pct / 100
			if pub != 0 and state.companies.has(c.party_b):
				var publisher: Company = state.companies[c.party_b]
				publisher.money += pub
				ctx.emit(&"money_changed", {"company_id": publisher.id, "money": publisher.money})
	var roy: int = Fixed.mul_bp(gross, royalty_bp(state, ctx.content, p))
	var net: int = gross - pub - roy
	p.revenue += net
	ctx.emit(&"sales_updated", {"project_id": p.id, "units": units, "revenue": net})
	if state.companies.has(p.company_id):
		var company: Company = state.companies[p.company_id]
		company.money += net
		ctx.emit(&"money_changed", {"company_id": company.id, "money": company.money})
	return net


static func tick(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var content: ContentDB = ctx.content
	var t: TuningDef = ctx.tuning
	for pid: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[pid]
		if p.kind != Project.Kind.GAME:
			continue
		if p.phase != Project.Phase.RELEASED and p.phase != Project.Phase.LIVE:
			continue
		if not content.sizes.has(p.size_id):
			continue
		var base: int
		if p.weekly_units.is_empty():
			base = launch_units(state, content, t, p)
			p.phase = Project.Phase.LIVE
			ctx.emit(&"project_phase_changed", {"project_id": pid, "phase": "LIVE"})
		else:
			base = Fixed.mul_bp(p.sales_base_units, decay_bp(content, t, p, state.week))
		if base < t.sales_floor_units:
			p.phase = Project.Phase.RETIRED
			ctx.emit(&"project_phase_changed", {"project_id": pid, "phase": "RETIRED"})
			continue
		p.sales_base_units = base
		var units: int = base
		if promo_active(p, state.week):
			units = Fixed.mul_bp(base, promo_uplift_bp(t, p.promo_discount_bp))
		p.weekly_units.append(units)
		while p.weekly_units.size() > Project.WEEKLY_UNITS_CAP:
			p.weekly_units.remove_at(0)
		book_sale(ctx, p, units, unit_price(content, p, state.week))
