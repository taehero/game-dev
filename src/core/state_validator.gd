class_name StateValidator
extends RefCounted
## Validates a parsed-JSON state dictionary: every key and type (spec 9.1),
## enum names, and reference integrity. GameState.from_dict crashes on bad input,
## so this must reject anything from_dict cannot read.

## Contract target points are whole numbers of at least this.
const MIN_TARGET_POINTS: int = 0

const STATE_SCHEMA: Dictionary = {
	"schema_version": "int",
	"week": "int",
	"rng_seed": "string",
	"rng_state": "string",
	"next_id": "int",
	"player_company_id": "int",
	"companies": "dict",
	"staff": "dict",
	"projects": "dict",
	"contracts": "dict",
	"owner": "dict",
	"equipment": "dict",
	"engines": "dict",
	"loans": "dict",
	"candidates": "array",
	"game_over": "bool",
	"market": "dict",
	"active_events": "array",
	"forum_posts": "array",
	"pending_decisions": "array",
}


static func validate(d: Variant) -> bool:
	if not SaveSchema.check(d, STATE_SCHEMA):
		return false
	var s: Dictionary = d
	if not (_canonical_int(String(s["rng_seed"])) and _canonical_int(String(s["rng_state"]))):
		return false
	var company_ids: Dictionary[int, bool] = {}
	var used: Array[int] = []
	if not _entities(s["companies"], Company.SCHEMA, used, company_ids, _company_ok):
		return false
	var staff_ids: Dictionary[int, bool] = {}
	if not _entities(s["staff"], Staff.SCHEMA, used, staff_ids, _staff_ok):
		return false
	var project_ids: Dictionary[int, bool] = {}
	if not _entities(s["projects"], Project.SCHEMA, used, project_ids, _project_ok):
		return false
	var contract_ids: Dictionary[int, bool] = {}
	if not _entities(s["contracts"], Contract.SCHEMA, used, contract_ids, _contract_ok):
		return false
	if not SaveSchema.check(s["owner"], OwnerProfile.SCHEMA):
		return false
	var owner_d: Dictionary = s["owner"]
	if not _whole_values(owner_d["perks"]):
		return false
	var focus_dev: int = int(owner_d["focus_dev_bp"])
	if focus_dev < 0 or focus_dev > 10000:
		return false
	var equipment_ids: Dictionary[int, bool] = {}
	if not _entities(s["equipment"], Equipment.SCHEMA, used, equipment_ids, _equipment_ok):
		return false
	var engine_ids: Dictionary[int, bool] = {}
	if not _entities(s["engines"], GameEngine.SCHEMA, used, engine_ids, _engine_ok):
		return false
	var loan_ids: Dictionary[int, bool] = {}
	if not _entities(s["loans"], Loan.SCHEMA, used, loan_ids, _always):
		return false
	if not _list(s["candidates"], Candidate.SCHEMA, used, true, _candidate_ok):
		return false
	if not _market_ok(s["market"]):
		return false
	if not _list(s["active_events"], ActiveWorldEvent.SCHEMA, used, false, _always):
		return false
	if not _list(s["forum_posts"], ForumPost.SCHEMA, used, true, _always):
		return false
	if not _list(s["pending_decisions"], Decision.SCHEMA, used, true, _decision_ok):
		return false
	# Reference integrity.
	if not company_ids.has(int(s["player_company_id"])):
		return false
	var staff_d: Dictionary = s["staff"]
	for k: Variant in staff_d:
		var e: Dictionary = staff_d[k]
		if not company_ids.has(int(e["company_id"])):
			return false
		var ap: int = int(e["assigned_project_id"])
		if ap != -1 and not project_ids.has(ap):
			return false
	var projects_d: Dictionary = s["projects"]
	for k: Variant in projects_d:
		var pe: Dictionary = projects_d[k]
		if not company_ids.has(int(pe["company_id"])):
			return false
		var eng_ref: int = int(pe["engine_id"])
		if eng_ref != -1 and not engine_ids.has(eng_ref):
			return false
		var cid: int = int(pe["contract_id"])
		if cid != -1 and not contract_ids.has(cid):
			return false
	var contracts_d: Dictionary = s["contracts"]
	for k: Variant in contracts_d:
		var e: Dictionary = contracts_d[k]
		if not company_ids.has(int(e["party_a"])) or not company_ids.has(int(e["party_b"])):
			return false
		var pid: int = int(e["project_id"])
		if pid != -1 and not project_ids.has(pid):
			return false
	if not _m2_refs_ok(s, company_ids, staff_ids):
		return false
	for post: Variant in s["forum_posts"]:
		if not project_ids.has(int(post["project_id"])):
			return false
	var next_id: int = int(s["next_id"])
	var seen: Dictionary[int, bool] = {}
	for id: int in used:
		if id <= 0 or next_id <= id or seen.has(id):
			return false
		seen[id] = true
	for dec: Variant in s["pending_decisions"]:
		for r: Variant in dec["related_ids"]:
			if not seen.has(int(r)):
				return false
	return true


static func _m2_refs_ok(
	s: Dictionary, company_ids: Dictionary[int, bool], staff_ids: Dictionary[int, bool]
) -> bool:
	var owner_id: int = int(s["owner"]["staff_id"])
	if not staff_ids.has(owner_id):
		return false
	var staff_d: Dictionary = s["staff"]
	var owner_count: int = 0
	var seats: Dictionary = {}
	for k: Variant in staff_d:
		var e: Dictionary = staff_d[k]
		if bool(e["is_owner"]):
			owner_count += 1
		var seat: int = int(e["seat_index"])
		if seat >= 0:
			var key: String = "s%d:%d" % [int(e["company_id"]), seat]
			if seats.has(key):
				return false
			seats[key] = true
	if owner_count != 1:
		return false
	var owner_e: Dictionary = staff_d[str(owner_id)]
	if not bool(owner_e["is_owner"]) or int(owner_e["company_id"]) != int(s["player_company_id"]):
		return false
	var equip_seats: Dictionary = {}
	var equipment_d: Dictionary = s["equipment"]
	for k: Variant in equipment_d:
		var e: Dictionary = equipment_d[k]
		if not company_ids.has(int(e["company_id"])):
			return false
		var seat: int = int(e["seat_index"])
		if seat >= 0:
			var key: String = "e%d:%d" % [int(e["company_id"]), seat]
			if equip_seats.has(key):
				return false
			equip_seats[key] = true
	var engines_d: Dictionary = s["engines"]
	for k: Variant in engines_d:
		if not company_ids.has(int(engines_d[k]["company_id"])):
			return false
	var companies_d: Dictionary = s["companies"]
	var loans_d: Dictionary = s["loans"]
	for k: Variant in loans_d:
		var e: Dictionary = loans_d[k]
		if not company_ids.has(int(e["company_id"])):
			return false
		var lender_id: int = int(e["lender_id"])
		if not company_ids.has(lender_id):
			return false
		var lk: String = String(companies_d[str(lender_id)]["kind"])
		if lk != "BANK" and lk != "LENDER":
			return false
	return true


## True when x is exactly what str(int) would produce: digits only, optional "-", no "+",
## no leading zeros, within 64-bit range. Checked on the text, because to_int() itself errors
## on overflow.
static func _canonical_int(x: String) -> bool:
	var neg: bool = x.begins_with("-")
	var digits: String = x.substr(1) if neg else x
	if digits.is_empty() or not digits.is_valid_int() or digits.begins_with("+"):
		return false
	if digits.begins_with("-") or (digits.length() > 1 and digits.begins_with("0")):
		return false
	if neg and digits == "0":
		return false
	if digits.length() > 19:
		return false
	if digits.length() == 19:
		var limit: String = "9223372036854775808" if neg else "9223372036854775807"
		return digits <= limit
	return true


## Validates a dictionary keyed by str(id). Records ids.
static func _entities(
	d: Dictionary, schema: Dictionary, used: Array[int], ids: Dictionary[int, bool], extra: Callable
) -> bool:
	for k: Variant in d:
		var key: String = String(k)
		if not _canonical_int(key):
			return false
		var e: Variant = d[k]
		if not SaveSchema.check(e, schema):
			return false
		var ed: Dictionary = e
		if int(ed["id"]) != key.to_int():
			return false
		if not extra.call(ed):
			return false
		ids[key.to_int()] = true
		used.append(key.to_int())
	return true


static func _list(
	a: Array, schema: Dictionary, used: Array[int], has_id: bool, extra: Callable
) -> bool:
	for e: Variant in a:
		if not SaveSchema.check(e, schema):
			return false
		var ed: Dictionary = e
		if not extra.call(ed):
			return false
		if has_id:
			used.append(int(ed["id"]))
	return true


static func _always(_e: Dictionary) -> bool:
	return true


static func _enum_ok(names: Array, v: Variant) -> bool:
	return (typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME) and names.has(String(v))


static func _whole_values(d: Dictionary) -> bool:
	for k: Variant in d:
		if not SaveSchema.is_whole(d[k]):
			return false
	return true


static func _strings_ok(a: Array) -> bool:
	for v: Variant in a:
		if typeof(v) != TYPE_STRING:
			return false
	return true


## Keys are a subset of SKILL_KEYS and every value is a whole number >= min_value.
static func _skill_map_ok(d: Dictionary, min_value: int) -> bool:
	for k: Variant in d:
		if typeof(k) != TYPE_STRING or not GameRules.SKILL_ORDER.has(StringName(String(k))):
			return false
		if not SaveSchema.is_whole(d[k]) or int(d[k]) < min_value:
			return false
	return true


static func _company_ok(e: Dictionary) -> bool:
	if not _enum_ok(Company.Kind.keys(), e["kind"]):
		return false
	if not (_strings_ok(e["unlocked"]) and _strings_ok(e["dev_kits"]) and _strings_ok(e["awards"])):
		return false
	return int(e["research_points"]) >= 0 and int(e["months_negative"]) >= 0


static func _contract_ok(e: Dictionary) -> bool:
	if not _enum_ok(Contract.Kind.keys(), e["kind"]):
		return false
	if not _skill_map_ok(e["target_points"], MIN_TARGET_POINTS):
		return false
	var q: int = int(e["quality_roll"])
	return q >= 0 and q <= 100


static func _staff_ok(e: Dictionary) -> bool:
	if not _enum_ok(Staff.Role.keys(), e["role"]):
		return false
	if not _enum_ok(Staff.Level.keys(), e["level"]):
		return false
	if not (_skill_map_ok(e["exp"], 0) and _skill_map_ok(e["week_points"], 0)):
		return false
	if int(e["seat_index"]) < -1:
		return false
	var skills: Dictionary = e["skills"]
	if not _whole_values(skills) or skills.size() != GameRules.SKILL_ORDER.size():
		return false
	for sk: StringName in GameRules.SKILL_ORDER:
		if not skills.has(String(sk)):
			return false
	for t: Variant in e["traits"]:
		if typeof(t) != TYPE_STRING:
			return false
	return true


static func _project_ok(e: Dictionary) -> bool:
	if not _enum_ok(Project.Phase.keys(), e["phase"]):
		return false
	var cfg: Dictionary = e["config"]
	for k: Variant in cfg:
		if typeof(cfg[k]) != TYPE_STRING:
			return false
	if not _enum_ok(Project.Kind.keys(), e["kind"]):
		return false
	var focus: Array = e["focus"]
	if focus.size() != 9:
		return false
	for f: Variant in focus:
		if not SaveSchema.is_whole(f) or int(f) < 0 or int(f) > 10000:
			return false
	for i: int in 3:
		if not GameRules.stage_sliders_ok(focus, i):
			return false
	var kind: Project.Kind = Project.Kind[String(e["kind"])]
	var stage: int = int(e["stage_index"])
	if stage < 0 or stage >= GameRules.stage_count_of_kind(kind):
		return false
	var progress: int = int(e["stage_progress"])
	if progress < 0 or progress > 10000:
		return false
	if not _strings_ok(e["event_ids"]):
		return false
	if not _strings_ok(e["features"]):
		return false
	for r: Variant in e["review_results"]:
		if not SaveSchema.check(r, ReviewResult.SCHEMA):
			return false
		var rd: Dictionary = r
		if int(rd["score_x10"]) < 10 or int(rd["score_x10"]) > 100:
			return false
	var units: Array = e["weekly_units"]
	if units.size() > Project.WEEKLY_UNITS_CAP:
		return false
	for u: Variant in units:
		if not SaveSchema.is_whole(u) or int(u) < 0:
			return false
	if int(e["dlc_count"]) < 0 or int(e["promo_until_week"]) < -1:
		return false
	var promo: int = int(e["promo_discount_bp"])
	if promo < 0 or promo > 10000:
		return false
	var eng: int = int(e["engine_id"])
	if eng != -1 and eng < 1:
		return false
	return _whole_values(e["points"])


static func _equipment_ok(e: Dictionary) -> bool:
	return _enum_ok(Equipment.Ownership.keys(), e["ownership"]) and int(e["seat_index"]) >= -1


static func _engine_ok(e: Dictionary) -> bool:
	if not _enum_ok(GameEngine.Source.keys(), e["source"]):
		return false
	if not _strings_ok(e["features"]):
		return false
	var cap: int = int(e["tech_cap"])
	return cap >= 0 and cap <= 100


static func _candidate_ok(e: Dictionary) -> bool:
	var level: int = int(e["level"])
	if level < 0 or level >= Staff.Level.size():
		return false
	var skills: Dictionary = e["skills"]
	if not _whole_values(skills) or skills.size() != GameRules.SKILL_ORDER.size():
		return false
	for sk: StringName in GameRules.SKILL_ORDER:
		if not skills.has(String(sk)):
			return false
	return _strings_ok(e["traits"])


static func _decision_ok(e: Dictionary) -> bool:
	for r: Variant in e["related_ids"]:
		if not SaveSchema.is_whole(r):
			return false
	for o: Variant in e["option_keys"]:
		if typeof(o) != TYPE_STRING:
			return false
	return true


static func _market_ok(m: Variant) -> bool:
	if not SaveSchema.check(m, Market.SCHEMA):
		return false
	var md: Dictionary = m
	for key: String in ["segment_size", "segment_growth_bp", "taste_bp", "platform_install_base"]:
		if not _whole_values(md[key]):
			return false
	var drift: Dictionary = md["focus_drift"]
	for k: Variant in drift:
		var arr: Variant = drift[k]
		if typeof(arr) != TYPE_ARRAY:
			return false
		var a: Array = arr
		if a.size() != 3:
			return false
		for v: Variant in a:
			if not SaveSchema.is_whole(v):
				return false
	return true
