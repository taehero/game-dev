class_name SignOutsourceCommand
extends Command

const PART_TYPES: Array[StringName] = [&"art", &"audio"]

var company_id: int
var vendor_id: int
var project_id: int = -1
var deliverable: StringName = &"engine"
var features: Array[StringName] = []


static func engine(p_company_id: int, p_vendor_id: int, p_features: Array[StringName]) -> SignOutsourceCommand:
	var c := SignOutsourceCommand.new()
	c.company_id = p_company_id
	c.vendor_id = p_vendor_id
	c.features = p_features.duplicate()
	return c


static func part(p_company_id: int, p_vendor_id: int, p_project_id: int, p_deliverable: StringName) -> SignOutsourceCommand:
	var c := SignOutsourceCommand.new()
	c.company_id = p_company_id
	c.vendor_id = p_vendor_id
	c.project_id = p_project_id
	c.deliverable = p_deliverable
	return c


func _price(state: GameState, tuning: TuningDef, content: ContentDB) -> int:
	if deliverable == &"engine":
		return tuning.outsource_engine_base_price + _feature_weeks(content) * tuning.outsource_price_per_feature_week
	return Fixed.mul_bp(tuning.outsource_part_price, content.sizes[state.projects[project_id].size_id].cost_multiplier_bp)


func _feature_weeks(content: ContentDB) -> int:
	var w: int = 0
	for f: StringName in features:
		w += content.engine_features[f].dev_weeks
	return w


func validate(state: GameState, tuning: TuningDef) -> CommandResult:
	var content: ContentDB = ContentDB.active()
	if not state.companies.has(company_id):
		return CommandResult.fail(&"error.company_not_found")
	if not state.companies.has(vendor_id) or state.companies[vendor_id].kind != Company.Kind.VENDOR:
		return CommandResult.fail(&"error.vendor_not_found")
	if deliverable == &"engine":
		if features.is_empty():
			return CommandResult.fail(&"error.no_features")
		for f: StringName in features:
			if not content.engine_features.has(f):
				return CommandResult.fail(&"error.feature_not_found")
			if features.count(f) > 1:
				return CommandResult.fail(&"error.duplicate_feature")
			if not GameRules.is_unlocked(state, content, company_id, f):
				return CommandResult.fail(&"error.item_locked")
	else:
		if not state.projects.has(project_id) or state.projects[project_id].company_id != company_id \
				or state.projects[project_id].kind != Project.Kind.GAME:
			return CommandResult.fail(&"error.project_not_found")
		if state.projects[project_id].phase != Project.Phase.PRODUCTION:
			return CommandResult.fail(&"error.project_not_in_production")
		if not PART_TYPES.has(deliverable):
			return CommandResult.fail(&"error.invalid_deliverable")
		for cid: int in state.sorted_ids(state.contracts):
			var c: Contract = state.contracts[cid]
			if c.kind == Contract.Kind.OUTSOURCE and c.project_id == project_id and c.deliverable == deliverable:
				return CommandResult.fail(&"error.already_outsourced")
	if state.companies[company_id].money < _price(state, tuning, content):
		return CommandResult.fail(&"error.not_enough_money")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	var t: TuningDef = ctx.tuning
	var c := Contract.new()
	c.id = state.alloc_id()
	c.kind = Contract.Kind.OUTSOURCE
	c.party_a = company_id
	c.party_b = vendor_id
	c.deliverable = deliverable
	c.price = _price(state, t, ctx.content)
	c.quality_roll = ctx.rng.randi_range(0, 100)
	if deliverable == &"engine":
		var late: int = 0
		if c.quality_roll < t.outsource_late_roll_below:
			late = ctx.rng.randi_range(1, t.outsource_max_late_weeks)
		c.features = features.duplicate()
		c.delivery_week = state.week + _feature_weeks(ctx.content) + late
	else:
		var p: Project = state.projects[project_id]
		c.project_id = project_id
		var par: int = ctx.content.sizes[p.size_id].par_points
		c.target_points[deliverable] = Fixed.mul_bp(Fixed.mul_bp(par, t.outsource_part_par_bp), 5000 + c.quality_roll * 100)
		c.delivery_week = maxi(state.week + 1, p.deadline_week)
	state.contracts[c.id] = c
	var company: Company = state.companies[company_id]
	company.money -= c.price
	ctx.emit(&"money_changed", {"company_id": company_id, "money": company.money})
