class_name StartProjectCommand
extends Command

var company_id: int
var kind: Project.Kind = Project.Kind.GAME
var title: String
var size_id: StringName
var platform_id: StringName
var topic_id: StringName
var genre_id: StringName
var engine_id: int = -1
var licensed_engine_id: StringName = &""
var features: Array[StringName] = []


static func game(p_company_id: int, p_title: String, p_size_id: StringName, p_platform_id: StringName, p_topic_id: StringName, p_genre_id: StringName, p_engine_id: int, p_licensed_engine_id: StringName, p_features: Array[StringName]) -> StartProjectCommand:
	var c := StartProjectCommand.new()
	c.company_id = p_company_id
	c.kind = Project.Kind.GAME
	c.title = p_title
	c.size_id = p_size_id
	c.platform_id = p_platform_id
	c.topic_id = p_topic_id
	c.genre_id = p_genre_id
	c.engine_id = p_engine_id
	c.licensed_engine_id = p_licensed_engine_id
	c.features = p_features.duplicate()
	return c


static func engine(p_company_id: int, p_title: String, p_features: Array[StringName]) -> StartProjectCommand:
	var c := StartProjectCommand.new()
	c.company_id = p_company_id
	c.kind = Project.Kind.ENGINE
	c.title = p_title
	c.features = p_features.duplicate()
	return c


func validate(state: GameState, tuning: TuningDef) -> CommandResult:
	var content: ContentDB = ContentDB.active()
	if not state.companies.has(company_id):
		return CommandResult.fail(&"error.company_not_found")
	if title.strip_edges().is_empty():
		return CommandResult.fail(&"error.title_empty")
	if kind == Project.Kind.ENGINE:
		return _validate_engine(state, tuning, content)
	return _validate_game(state, tuning, content)


func _validate_game(state: GameState, tuning: TuningDef, content: ContentDB) -> CommandResult:
	if not content.sizes.has(size_id):
		return CommandResult.fail(&"error.size_not_found")
	if not GameRules.is_unlocked(state, content, company_id, size_id):
		return CommandResult.fail(&"error.item_locked")
	if not content.platforms.has(platform_id):
		return CommandResult.fail(&"error.platform_not_found")
	if GameRules.platform_status(content.platforms[platform_id], state.week) != GameRules.PlatformStatus.ON_SALE:
		return CommandResult.fail(&"error.platform_not_on_sale")
	if not GameRules.has_dev_kit(state, content, company_id, platform_id):
		return CommandResult.fail(&"error.no_dev_kit")
	if not content.topics.has(topic_id):
		return CommandResult.fail(&"error.topic_not_found")
	if not GameRules.is_unlocked(state, content, company_id, topic_id):
		return CommandResult.fail(&"error.item_locked")
	if not content.genres.has(genre_id):
		return CommandResult.fail(&"error.genre_not_found")
	if not GameRules.is_unlocked(state, content, company_id, genre_id):
		return CommandResult.fail(&"error.item_locked")
	if engine_id != -1:
		if not state.engines.has(engine_id) or state.engines[engine_id].company_id != company_id:
			return CommandResult.fail(&"error.engine_unavailable")
	elif not GameRules.licensed_engine_available(state, content, company_id, licensed_engine_id, state.week, tuning):
		return CommandResult.fail(&"error.engine_unavailable")
	var supported: Array[StringName] = GameRules.engine_features(state, content, engine_id, licensed_engine_id)
	for f: StringName in features:
		if not content.engine_features.has(f):
			return CommandResult.fail(&"error.feature_not_found")
		if not GameRules.is_unlocked(state, content, company_id, f):
			return CommandResult.fail(&"error.item_locked")
		if not supported.has(f):
			return CommandResult.fail(&"error.feature_not_in_engine")
	if GameRules.free_workers(state, company_id).size() < content.sizes[size_id].min_staff:
		return CommandResult.fail(&"error.not_enough_staff")
	return CommandResult.success()


func _validate_engine(state: GameState, tuning: TuningDef, content: ContentDB) -> CommandResult:
	if features.is_empty():
		return CommandResult.fail(&"error.no_features")
	for f: StringName in features:
		if not content.engine_features.has(f):
			return CommandResult.fail(&"error.feature_not_found")
		if not GameRules.is_unlocked(state, content, company_id, f):
			return CommandResult.fail(&"error.item_locked")
	if GameRules.free_workers(state, company_id).size() < tuning.engine_min_staff:
		return CommandResult.fail(&"error.not_enough_staff")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var p := Project.new()
	p.id = ctx.state.alloc_id()
	p.company_id = company_id
	p.title = title
	p.kind = kind
	p.phase = Project.Phase.PRODUCTION
	p.stage_index = 0
	p.stage_progress = 0
	p.features = features.duplicate()
	p.engine_id = engine_id
	if kind == Project.Kind.GAME:
		p.size_id = size_id
		var cfg: Dictionary[StringName, StringName] = {
			&"engine": licensed_engine_id if engine_id == -1 else &"",
			&"genre": genre_id,
			&"platform": platform_id,
			&"topic": topic_id,
		}
		for k: StringName in GameState.sorted_names(cfg):
			p.config[k] = cfg[k]
		p.focus = Project.DEFAULT_FOCUS.duplicate()
	else:
		p.size_id = &""
		p.engine_id = -1
		p.focus = GameRules.ENGINE_FOCUS.duplicate()
	p.deadline_week = ctx.state.week + GameRules.stage_count(p) * GameRules.stage_weeks(p, ctx.content, ctx.tuning)
	for sid: int in GameRules.free_workers(ctx.state, company_id):
		ctx.state.staff[sid].assigned_project_id = p.id
	ctx.state.projects[p.id] = p
	ctx.emit(&"project_phase_changed", {"project_id": p.id, "phase": "PRODUCTION"})
