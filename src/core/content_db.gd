class_name ContentDB
extends RefCounted
## Read-only content indexes (M2 spec, Ruling A1). Content is immutable after load.

const DEFAULT_ROOT: String = "res://data"

static var _active: ContentDB = null

var platforms: Dictionary[StringName, PlatformDef] = {}
var genres: Dictionary[StringName, GenreDef] = {}
var topics: Dictionary[StringName, TopicDef] = {}
var outlets: Dictionary[StringName, ReviewOutletDef] = {}
var review_templates: Dictionary[StringName, ReviewTemplateDef] = {}
var offices: Dictionary[StringName, OfficeDef] = {}
var equipment: Dictionary[StringName, EquipmentDef] = {}
var engine_features: Dictionary[StringName, EngineFeatureDef] = {}
var licensed_engines: Dictionary[StringName, LicensedEngineDef] = {}
var research: Dictionary[StringName, ResearchDef] = {}
var sizes: Dictionary[StringName, ProjectSizeDef] = {}
var levels: Dictionary[StringName, LevelDef] = {}
var perks: Dictionary[StringName, PerkDef] = {}
var channels: Dictionary[StringName, MarketingChannelDef] = {}
var awards: Dictionary[StringName, AwardDef] = {}
var production_events: Dictionary[StringName, ProductionEventDef] = {}
var errors: Array[String] = []

var _ids: Dictionary[StringName, bool] = {}


static func active() -> ContentDB:
	if _active == null:
		_active = load_dir()
	return _active


static func use(db: ContentDB) -> void:
	_active = db


## Recursive, sorted `.tres` paths. Exported builds rename `x.tres` to `x.tres.remap`.
static func content_paths(root: String) -> Array[String]:
	var found: Dictionary[String, bool] = {}
	_scan(root, found)
	var out: Array[String] = []
	for p: String in found:
		out.append(p)
	out.sort()
	return out


static func _scan(dir: String, found: Dictionary[String, bool]) -> void:
	for f: String in DirAccess.get_files_at(dir):
		var name := f
		if name.ends_with(".remap"):
			name = name.trim_suffix(".remap")
		if name.ends_with(".tres"):
			found[dir.path_join(name)] = true
	for d: String in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(d), found)


static func load_dir(root: String = DEFAULT_ROOT) -> ContentDB:
	var db := ContentDB.new()
	for path: String in content_paths(root):
		var res: Resource = load(path)
		if res is TuningDef:
			continue
		if res == null or not db._is_known(res):
			db.errors.append("unknown content type: %s" % path)
			continue
		db.add(res)
	return db


func _is_known(def: Resource) -> bool:
	return (def is PlatformDef or def is GenreDef or def is TopicDef or def is ReviewOutletDef
		or def is ReviewTemplateDef or def is OfficeDef or def is EquipmentDef
		or def is EngineFeatureDef or def is LicensedEngineDef or def is ResearchDef
		or def is ProjectSizeDef or def is LevelDef or def is PerkDef
		or def is MarketingChannelDef or def is AwardDef or def is ProductionEventDef)


func add(def: Resource) -> bool:
	if not _is_known(def):
		errors.append("unknown content type: %s" % def.get_class())
		return false
	var id: StringName = def.get(&"id")
	if _ids.has(id):
		errors.append("duplicate id: %s" % id)
		push_error("duplicate content id: %s" % id)
		return false
	_ids[id] = true
	if def is PlatformDef:
		platforms[id] = def
	elif def is GenreDef:
		genres[id] = def
	elif def is TopicDef:
		topics[id] = def
	elif def is ReviewOutletDef:
		outlets[id] = def
	elif def is ReviewTemplateDef:
		review_templates[id] = def
	elif def is OfficeDef:
		offices[id] = def
	elif def is EquipmentDef:
		equipment[id] = def
	elif def is EngineFeatureDef:
		engine_features[id] = def
	elif def is LicensedEngineDef:
		licensed_engines[id] = def
	elif def is ResearchDef:
		research[id] = def
	elif def is ProjectSizeDef:
		sizes[id] = def
	elif def is LevelDef:
		levels[id] = def
	elif def is PerkDef:
		perks[id] = def
	elif def is MarketingChannelDef:
		channels[id] = def
	elif def is ProductionEventDef:
		production_events[id] = def
	else:
		awards[id] = def
	return true


func level_def(level: int) -> LevelDef:
	for id: StringName in GameState.sorted_names(levels):
		if levels[id].level == level:
			return levels[id]
	return null


func locking_research(item_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in GameState.sorted_names(research):
		if research[id].unlocks.has(item_id):
			out.append(id)
	return out


## Ruling A11: unlocked when nothing locks it, or one of its research is done.
func is_unlocked(done: Array[StringName], item_id: StringName) -> bool:
	var locks: Array[StringName] = locking_research(item_id)
	if locks.is_empty():
		return true
	for r: StringName in locks:
		if done.has(r):
			return true
	return false


## One message per content id in the state that this DB does not know.
func missing_refs(state: GameState) -> Array[String]:
	var out: Array[String] = []
	for cid: int in state.sorted_ids(state.companies):
		var c: Company = state.companies[cid]
		if c.office_id != &"" and not offices.has(c.office_id):
			out.append("company %d: unknown office %s" % [cid, c.office_id])
		for r: StringName in c.unlocked:
			if not research.has(r):
				out.append("company %d: unknown research %s" % [cid, r])
		for a: StringName in c.awards:
			if not awards.has(a):
				out.append("company %d: unknown award %s" % [cid, a])
		for p: StringName in c.dev_kits:
			if not platforms.has(p):
				out.append("company %d: unknown platform %s" % [cid, p])
	for eid: int in state.sorted_ids(state.equipment):
		var e: Equipment = state.equipment[eid]
		if not equipment.has(e.def_id):
			out.append("equipment %d: unknown def %s" % [eid, e.def_id])
		_check_seat(out, state, "equipment", eid, e.company_id, e.seat_index)
	for sid: int in state.sorted_ids(state.staff):
		var st: Staff = state.staff[sid]
		_check_seat(out, state, "staff", sid, st.company_id, st.seat_index)
	for pid: int in state.sorted_ids(state.projects):
		var pr: Project = state.projects[pid]
		if pr.size_id != &"" and not sizes.has(pr.size_id):
			out.append("project %d: unknown size %s" % [pid, pr.size_id])
		var lookups: Array[Array] = [[&"platform", platforms], [&"genre", genres], [&"topic", topics],
			[&"engine", licensed_engines]]
		for pair: Array in lookups:
			var key: StringName = pair[0]
			var table: Dictionary = pair[1]
			var v: StringName = pr.config.get(key, &"")
			if v != &"" and not table.has(v):
				out.append("project %d: unknown %s %s" % [pid, key, v])
		for f: StringName in pr.features:
			if not engine_features.has(f):
				out.append("project %d: unknown feature %s" % [pid, f])
		for ev: StringName in pr.event_ids:
			if not production_events.has(ev):
				out.append("project %d: unknown event %s" % [pid, ev])
		for rr: ReviewResult in pr.review_results:
			if not outlets.has(rr.outlet_id):
				out.append("project %d: unknown outlet %s" % [pid, rr.outlet_id])
	for kid: int in state.sorted_ids(state.contracts):
		var ct: Contract = state.contracts[kid]
		if ct.locked_genre != &"" and not genres.has(ct.locked_genre):
			out.append("contract %d: unknown genre %s" % [kid, ct.locked_genre])
		if ct.locked_platform != &"" and not platforms.has(ct.locked_platform):
			out.append("contract %d: unknown platform %s" % [kid, ct.locked_platform])
		if ct.kind == Contract.Kind.ENGINE_LICENSE and not licensed_engines.has(ct.deliverable):
			out.append("contract %d: unknown engine %s" % [kid, ct.deliverable])
	for perk_id: StringName in GameState.sorted_names(state.owner.perks):
		if not perks.has(perk_id):
			out.append("owner: unknown perk %s" % perk_id)
	for gid: int in state.sorted_ids(state.engines):
		for f: StringName in state.engines[gid].features:
			if not engine_features.has(f):
				out.append("engine %d: unknown feature %s" % [gid, f])
	for dec: Decision in state.pending_decisions:
		if String(dec.kind).begins_with("pevent_") and not production_events.has(dec.kind):
			out.append("decision %d: unknown event %s" % [dec.id, dec.kind])
	return out


func _check_seat(out: Array[String], state: GameState, what: String, id: int, company_id: int, seat: int) -> void:
	if seat < 0 or not state.companies.has(company_id):
		return
	var office_id: StringName = state.companies[company_id].office_id
	if office_id != &"" and offices.has(office_id) and seat >= offices[office_id].seats:
		out.append("%s %d: seat %d beyond office %s" % [what, id, seat, office_id])


func validate() -> Array[String]:
	var errs: Array[String] = []
	for id: StringName in GameState.sorted_names(research):
		var r: ResearchDef = research[id]
		for p: StringName in r.prerequisites:
			if not research.has(p):
				errs.append("%s: unknown prerequisite %s" % [id, p])
		for u: StringName in r.unlocks:
			if not _ids.has(u):
				errs.append("%s: unknown unlock %s" % [id, u])
	for id: StringName in GameState.sorted_names(engine_features):
		var f: EngineFeatureDef = engine_features[id]
		if f.research_id != &"":
			if not research.has(f.research_id):
				errs.append("%s: unknown research %s" % [id, f.research_id])
			elif not research[f.research_id].unlocks.has(id):
				errs.append("%s: research %s does not unlock it" % [id, f.research_id])
	for id: StringName in GameState.sorted_names(licensed_engines):
		for f: StringName in licensed_engines[id].features:
			if not engine_features.has(f):
				errs.append("%s: unknown feature %s" % [id, f])
	for id: StringName in GameState.sorted_names(genres):
		var s: Array[int] = genres[id].ideal_sliders
		if s.size() != 9:
			errs.append("%s: ideal_sliders size %d, expected 9" % [id, s.size()])
			continue
		for stage: int in 3:
			if not GameRules.stage_sliders_ok(s, stage):
				var sum: int = s[stage * 3] + s[stage * 3 + 1] + s[stage * 3 + 2]
				errs.append("%s: stage %d sliders sum to %d" % [id, stage, sum])
	for id: StringName in GameState.sorted_names(topics):
		_check_fit(errs, id, topics[id].genre_fit_bp)
	for id: StringName in GameState.sorted_names(platforms):
		_check_fit(errs, id, platforms[id].genre_fit_bp)
	for id: StringName in GameState.sorted_names(outlets):
		var any_positive: bool = false
		var w: Dictionary[StringName, int] = outlets[id].weights_bp
		for dim: StringName in GameState.sorted_names(w):
			if not ReviewOutletDef.DIMENSIONS.has(dim):
				errs.append("%s: unknown dimension %s" % [id, dim])
			if w[dim] > 0:
				any_positive = true
		if not any_positive:
			errs.append("%s: no positive weight" % id)
	for id: StringName in GameState.sorted_names(review_templates):
		var dim: StringName = review_templates[id].dimension
		if dim != &"generic" and not ReviewOutletDef.DIMENSIONS.has(dim):
			errs.append("%s: unknown dimension %s" % [id, dim])
	for id: StringName in GameState.sorted_names(sizes):
		if sizes[id].base_weeks < 3:
			errs.append("%s: base_weeks below 3" % id)
		if sizes[id].min_staff < 1:
			errs.append("%s: min_staff below 1" % id)
	for id: StringName in GameState.sorted_names(production_events):
		_check_event(errs, id, production_events[id])
	return errs


func _check_event(errs: Array[String], id: StringName, ev: ProductionEventDef) -> void:
	if not String(id).begins_with("pevent_"):
		errs.append("%s: id must start with pevent_" % id)
	if ev.title_key == &"" or ev.body_key == &"":
		errs.append("%s: empty title_key or body_key" % id)
	var n: int = ev.option_keys.size()
	if n < 2 or n > 3:
		errs.append("%s: option_keys size %d, expected 2 or 3" % [id, n])
	for i: int in 3:
		var fx: Dictionary[StringName, int] = ev.option_effects(i)
		if i >= n and not fx.is_empty():
			errs.append("%s: option %d has effects but no option key" % [id, i + 1])
		for k: StringName in GameState.sorted_names(fx):
			if not ProductionEventDef.EFFECTS.has(k):
				errs.append("%s: unknown effect %s" % [id, k])
			elif absi(fx[k]) > ProductionEventDef.LIMITS[k]:
				errs.append("%s: effect %s out of range" % [id, k])


func _check_fit(errs: Array[String], id: StringName, fit: Dictionary[StringName, int]) -> void:
	for g: StringName in GameState.sorted_names(fit):
		if not genres.has(g):
			errs.append("%s: genre_fit_bp key %s is not a genre" % [id, g])
		if fit[g] < 5000 or fit[g] > 15000:
			errs.append("%s: genre_fit_bp %s out of range" % [id, g])
