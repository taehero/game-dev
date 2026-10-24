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
	s.companies[c.id] = c
	s.player_company_id = c.id
	return s


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
	for k: Variant in companies_in:
		s.companies[int(String(k))] = Company.from_dict(companies_in[k])
	var staff_in: Dictionary = d["staff"]
	for k: Variant in staff_in:
		s.staff[int(String(k))] = Staff.from_dict(staff_in[k])
	var projects_in: Dictionary = d["projects"]
	for k: Variant in projects_in:
		s.projects[int(String(k))] = Project.from_dict(projects_in[k])
	var contracts_in: Dictionary = d["contracts"]
	for k: Variant in contracts_in:
		s.contracts[int(String(k))] = Contract.from_dict(contracts_in[k])
	s.market = Market.from_dict(d["market"])
	for e: Variant in d["active_events"]:
		s.active_events.append(ActiveWorldEvent.from_dict(e))
	for f: Variant in d["forum_posts"]:
		s.forum_posts.append(ForumPost.from_dict(f))
	for dec: Variant in d["pending_decisions"]:
		s.pending_decisions.append(Decision.from_dict(dec))
	return s
