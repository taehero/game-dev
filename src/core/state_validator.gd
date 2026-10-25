class_name StateValidator
extends RefCounted
## Validates a parsed-JSON state dictionary: every key and type (spec 9.1),
## enum names, and reference integrity. GameState.from_dict crashes on bad input,
## so this must reject anything from_dict cannot read.

const SKILL_KEYS: Array[String] = ["art", "audio", "design", "tech"]

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
		if typeof(k) != TYPE_STRING or not SKILL_KEYS.has(String(k)):
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
	if not _skill_map_ok(e["target_points"], -9223372036854775807):
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
	if not _whole_values(skills) or skills.size() != SKILL_KEYS.size():
		return false
	for sk: String in SKILL_KEYS:
		if not skills.has(sk):
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
	var focus: Array = e["focus"]
	if focus.size() != 3:
		return false
	for f: Variant in focus:
		if not SaveSchema.is_whole(f):
			return false
	return _whole_values(e["points"])


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
