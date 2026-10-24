class_name Fixtures
extends RefCounted
## Shared test helpers. Not a test file.


static func json_round_trip(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d, "", true, true))


## Fresh defaults, so tests do not depend on edits to data/tuning.tres.
static func tuning() -> TuningDef:
	return TuningDef.new()


static func new_state(p_seed: int) -> GameState:
	return GameState.new_game(p_seed, "Test Studio", tuning())


static func add_staff(state: GameState, overrides: Dictionary = {}) -> int:
	var s := Staff.new()
	s.id = state.alloc_id()
	s.company_id = state.player_company_id
	s.name = "Staff %d" % s.id
	s.salary = 500
	for skill: StringName in [&"design", &"tech", &"art", &"audio"]:
		s.skills[skill] = 20
	for k: Variant in overrides:
		s.set(String(k), overrides[k])
	state.staff[s.id] = s
	return s.id


static func add_project(state: GameState, overrides: Dictionary = {}) -> int:
	var p := Project.new()
	p.id = state.alloc_id()
	p.company_id = state.player_company_id
	p.title = "Project %d" % p.id
	p.deadline_week = state.week + 24
	for k: Variant in overrides:
		p.set(String(k), overrides[k])
	state.projects[p.id] = p
	return p.id
