class_name MarketingSystem
extends RefCounted


## &"" when the channel can be booked now, else the error key.
static func channel_block_key(state: GameState, content: ContentDB, t: TuningDef, company_id: int, channel_id: StringName) -> StringName:
	if not content.channels.has(channel_id):
		return &"error.channel_not_found"
	if not GameRules.is_unlocked(state, content, company_id, channel_id):
		return &"error.item_locked"
	var def: MarketingChannelDef = content.channels[channel_id]
	var year: int = Calendar.year(state.week, t)
	if year < def.year_from or year > def.year_to:
		return &"error.channel_unavailable"
	if not def.weeks_in_year.is_empty() and not def.weeks_in_year.has(Calendar.week_in_year(state.week, t)):
		return &"error.channel_unavailable"
	return &""


## Channel hype scaled by the owner's Promoter perk.
static func hype_gain(state: GameState, content: ContentDB, channel: MarketingChannelDef) -> int:
	return Fixed.mul_bp(channel.hype_gain, Fixed.ONE_BP + PeopleRules.effect_bp(state, content, &"hype_gain_bp"))


## Latest promo_until_week over the company's projects, or -1.
static func last_promo_end(state: GameState, company_id: int) -> int:
	var latest: int = -1
	for pid: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[pid]
		if p.company_id == company_id:
			latest = maxi(latest, p.promo_until_week)
	return latest


static func tick(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	for pid: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[pid]
		if p.kind == Project.Kind.GAME and (p.phase == Project.Phase.PRODUCTION or p.phase == Project.Phase.POLISH):
			p.hype = Fixed.mul_bp(p.hype, ctx.tuning.hype_decay_bp)
	if Calendar.is_month_start(state.week, ctx.tuning):
		for cid: int in state.sorted_ids(state.companies):
			var c: Company = state.companies[cid]
			c.promo_fatigue = maxi(0, c.promo_fatigue - ctx.tuning.promo_fatigue_recovery_per_month)
