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
		or def is MarketingChannelDef or def is AwardDef)


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
			var sum: int = s[stage * 3] + s[stage * 3 + 1] + s[stage * 3 + 2]
			if sum != Fixed.ONE_BP:
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
	return errs


func _check_fit(errs: Array[String], id: StringName, fit: Dictionary[StringName, int]) -> void:
	for g: StringName in GameState.sorted_names(fit):
		if not genres.has(g):
			errs.append("%s: genre_fit_bp key %s is not a genre" % [id, g])
		if fit[g] < 5000 or fit[g] > 15000:
			errs.append("%s: genre_fit_bp %s out of range" % [id, g])
