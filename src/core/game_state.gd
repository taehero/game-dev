class_name GameState
extends RefCounted
## All mutable runtime data. Pure data, never a Node.

var schema_version: int = 1
var week: int = 0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var rng_seed: int = 0
var next_id: int = 1
var player_company_id: int = -1
var companies: Dictionary[int, Company] = {}
var staff: Dictionary[int, Staff] = {}
var projects: Dictionary[int, Project] = {}
var contracts: Dictionary[int, Contract] = {}
var owner: OwnerProfile = OwnerProfile.new()
var equipment: Dictionary[int, Equipment] = {}
var engines: Dictionary[int, GameEngine] = {}
var loans: Dictionary[int, Loan] = {}
var candidates: Array[Candidate] = []
var game_over: bool = false
var market: Market = Market.new()
var active_events: Array[ActiveWorldEvent] = []
var forum_posts: Array[ForumPost] = []
var pending_decisions: Array[Decision] = []


static func new_game(p_seed: int, studio_name: String, t: TuningDef) -> GameState:
	var s := GameState.new()
	s.rng_seed = p_seed
	s.rng.seed = p_seed
	var c := Company.new()
	c.id = s.alloc_id()
	c.name = studio_name
	c.kind = Company.Kind.PLAYER
	c.money = t.start_money
	c.reputation = 0
	c.office_id = t.start_office_id
	s.companies[c.id] = c
	s.player_company_id = c.id
	var o := Staff.new()
	o.id = s.alloc_id()
	o.company_id = c.id
	o.name = "ui.default_owner_name"
	o.is_owner = true
	o.seat_index = 0
	o.salary = 0
	var owner_skills: Dictionary[StringName, int] = {}
	for k: StringName in GameRules.SKILL_ORDER:
		owner_skills[k] = t.owner_start_skill
	o.set_skills(owner_skills)
	s.staff[o.id] = o
	var eq := Equipment.new()
	eq.id = s.alloc_id()
	eq.company_id = c.id
	eq.def_id = t.start_equipment_def
	eq.ownership = Equipment.Ownership.BOUGHT
	eq.seat_index = 0
	eq.value = t.start_equipment_value
	s.equipment[eq.id] = eq
	s.owner.staff_id = o.id
	var ai: Array = [
		[Company.Kind.BANK, "company.bank.name"],
		[Company.Kind.LENDER, "company.lender.name"],
		[Company.Kind.VENDOR, "company.vendor_1.name"],
		[Company.Kind.VENDOR, "company.vendor_2.name"],
		[Company.Kind.AI_PUBLISHER, "company.publisher_1.name"],
		[Company.Kind.AI_PUBLISHER, "company.publisher_2.name"],
		[Company.Kind.AI_PUBLISHER, "company.publisher_3.name"],
	]
	for spec: Array in ai:
		var a := Company.new()
		a.id = s.alloc_id()
		a.name = spec[1]
		a.kind = spec[0]
		a.office_id = &""
		s.companies[a.id] = a
	return s


func owner_staff_id() -> int:
	return owner.staff_id


func alloc_id() -> int:
	var id: int = next_id
	next_id += 1
	return id


func sorted_ids(d: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for k: Variant in d:
		out.append(int(k))
	out.sort()
	return out


## Name keys in ascending String order. Use for any iteration that changes state,
## draws RNG or breaks a tie (Ruling 14); static so from_dict can use it too.
static func sorted_names(d: Dictionary) -> Array[StringName]:
	var strs: Array[String] = []
	for k: Variant in d:
		strs.append(String(k))
	strs.sort()
	var out: Array[StringName] = []
	for k: String in strs:
		out.append(StringName(k))
	return out


func staff_of(company_id: int) -> Array[int]:
	var out: Array[int] = []
	for id: int in sorted_ids(staff):
		if staff[id].company_id == company_id:
			out.append(id)
	return out


func to_dict() -> Dictionary:
	var companies_out: Dictionary = {}
	for id: int in companies:
		companies_out[str(id)] = companies[id].to_dict()
	var staff_out: Dictionary = {}
	for id: int in staff:
		staff_out[str(id)] = staff[id].to_dict()
	var projects_out: Dictionary = {}
	for id: int in projects:
		projects_out[str(id)] = projects[id].to_dict()
	var contracts_out: Dictionary = {}
	for id: int in contracts:
		contracts_out[str(id)] = contracts[id].to_dict()
	var equipment_out: Dictionary = {}
	for id: int in equipment:
		equipment_out[str(id)] = equipment[id].to_dict()
	var engines_out: Dictionary = {}
	for id: int in engines:
		engines_out[str(id)] = engines[id].to_dict()
	var loans_out: Dictionary = {}
	for id: int in loans:
		loans_out[str(id)] = loans[id].to_dict()
	var candidates_out: Array = []
	for cand: Candidate in candidates:
		candidates_out.append(cand.to_dict())
	var events_out: Array = []
	for e: ActiveWorldEvent in active_events:
		events_out.append(e.to_dict())
	var posts_out: Array = []
	for f: ForumPost in forum_posts:
		posts_out.append(f.to_dict())
	var decisions_out: Array = []
	for dec: Decision in pending_decisions:
		decisions_out.append(dec.to_dict())
	return {
		"schema_version": schema_version,
		"week": week,
		"rng_seed": str(rng_seed),
		"rng_state": str(rng.state),
		"next_id": next_id,
		"player_company_id": player_company_id,
		"companies": companies_out,
		"staff": staff_out,
		"projects": projects_out,
		"contracts": contracts_out,
		"owner": owner.to_dict(),
		"equipment": equipment_out,
		"engines": engines_out,
		"loans": loans_out,
		"candidates": candidates_out,
		"game_over": game_over,
		"market": market.to_dict(),
		"active_events": events_out,
		"forum_posts": posts_out,
		"pending_decisions": decisions_out,
	}


static func validate_dict(d: Variant) -> bool:
	return StateValidator.validate(d)


## Assumes validate_dict(d) passed.
static func from_dict(d: Dictionary) -> GameState:
	var s := GameState.new()
	s.schema_version = int(d["schema_version"])
	s.week = int(d["week"])
	s.rng_seed = String(d["rng_seed"]).to_int()
	s.rng.seed = s.rng_seed
	s.rng.state = String(d["rng_state"]).to_int()
	s.next_id = int(d["next_id"])
	s.player_company_id = int(d["player_company_id"])
	var companies_in: Dictionary = d["companies"]
	for id: int in _sorted_keys(companies_in):
		s.companies[id] = Company.from_dict(companies_in[str(id)])
	var staff_in: Dictionary = d["staff"]
	for id: int in _sorted_keys(staff_in):
		s.staff[id] = Staff.from_dict(staff_in[str(id)])
	var projects_in: Dictionary = d["projects"]
	for id: int in _sorted_keys(projects_in):
		s.projects[id] = Project.from_dict(projects_in[str(id)])
	var contracts_in: Dictionary = d["contracts"]
	for id: int in _sorted_keys(contracts_in):
		s.contracts[id] = Contract.from_dict(contracts_in[str(id)])
	s.owner = OwnerProfile.from_dict(d["owner"])
	var equipment_in: Dictionary = d["equipment"]
	for id: int in _sorted_keys(equipment_in):
		s.equipment[id] = Equipment.from_dict(equipment_in[str(id)])
	var engines_in: Dictionary = d["engines"]
	for id: int in _sorted_keys(engines_in):
		s.engines[id] = GameEngine.from_dict(engines_in[str(id)])
	var loans_in: Dictionary = d["loans"]
	for id: int in _sorted_keys(loans_in):
		s.loans[id] = Loan.from_dict(loans_in[str(id)])
	for cand: Variant in d["candidates"]:
		s.candidates.append(Candidate.from_dict(cand))
	s.game_over = bool(d["game_over"])
	s.market = Market.from_dict(d["market"])
	for e: Variant in d["active_events"]:
		s.active_events.append(ActiveWorldEvent.from_dict(e))
	for f: Variant in d["forum_posts"]:
		s.forum_posts.append(ForumPost.from_dict(f))
	for dec: Variant in d["pending_decisions"]:
		s.pending_decisions.append(Decision.from_dict(dec))
	return s


## JSON keys in ascending int order, so load inserts in allocation order like a live game.
static func _sorted_keys(d: Dictionary) -> Array[int]:
	var out: Array[int] = []
	for k: Variant in d:
		out.append(int(String(k)))
	out.sort()
	return out
