class_name GameRules
extends RefCounted
## Read-only rule helpers shared by commands, systems and StateQueries. None mutates state.

enum PlatformStatus { UNANNOUNCED, RUMORED, ON_SALE, RETIRED }

## Spec 6.3: point type of each of the nine sliders, in focus index order.
const SLIDER_TYPES: Array[StringName] = [&"tech", &"design", &"design", &"design", &"art", &"tech", &"art", &"audio", &"tech"]
## All Code, so engine work produces tech points. Duplicate before storing.
## Point/skill types in the fixed RNG draw order (design, tech, art, audio).
const SKILL_ORDER: Array[StringName] = [&"design", &"tech", &"art", &"audio"]
const ENGINE_FOCUS: Array[int] = [10000, 0, 0, 10000, 0, 0, 10000, 0, 0]


static func platform_status(def: PlatformDef, week: int) -> PlatformStatus:
	if week >= def.end_week:
		return PlatformStatus.RETIRED
	if week >= def.launch_week:
		return PlatformStatus.ON_SALE
	if def.rumor_weeks > 0 and week >= def.launch_week - def.rumor_weeks:
		return PlatformStatus.RUMORED
	return PlatformStatus.UNANNOUNCED


## Ruling A11: a free dev kit (cost 0) counts as owned.
static func has_dev_kit(state: GameState, content: ContentDB, company_id: int, platform_id: StringName) -> bool:
	if not content.platforms.has(platform_id) or not state.companies.has(company_id):
		return false
	if content.platforms[platform_id].dev_kit_cost == 0:
		return true
	return state.companies[company_id].dev_kits.has(platform_id)


static func is_unlocked(state: GameState, content: ContentDB, company_id: int, item_id: StringName) -> bool:
	if not state.companies.has(company_id):
		return false
	return content.is_unlocked(state.companies[company_id].unlocked, item_id)


static func office_seats(state: GameState, content: ContentDB, company_id: int) -> int:
	if not state.companies.has(company_id):
		return 0
	var office_id: StringName = state.companies[company_id].office_id
	if not content.offices.has(office_id):
		return 0
	return content.offices[office_id].seats


static func free_seat(state: GameState, content: ContentDB, company_id: int) -> int:
	var seats: int = office_seats(state, content, company_id)
	var used: Dictionary[int, bool] = {}
	for sid: int in state.sorted_ids(state.staff):
		var st: Staff = state.staff[sid]
		if st.company_id == company_id and st.seat_index >= 0:
			used[st.seat_index] = true
	for seat: int in seats:
		if not used.has(seat):
			return seat
	return -1


## Equipment id at the seat, or -1. Lowest id wins when two share a seat.
static func equipment_at_seat(state: GameState, company_id: int, seat: int) -> int:
	if seat < 0:
		return -1
	for eid: int in state.sorted_ids(state.equipment):
		var e: Equipment = state.equipment[eid]
		if e.company_id == company_id and e.seat_index == seat:
			return eid
	return -1


static func free_workers(state: GameState, company_id: int) -> Array[int]:
	var out: Array[int] = []
	for sid: int in state.sorted_ids(state.staff):
		var st: Staff = state.staff[sid]
		if st.company_id != company_id or st.assigned_project_id != -1:
			continue
		if st.seat_index >= 0 and equipment_at_seat(state, company_id, st.seat_index) != -1:
			out.append(sid)
	return out


static func working_staff(state: GameState, project_id: int) -> Array[int]:
	var out: Array[int] = []
	if project_id < 0:
		return out
	for sid: int in state.sorted_ids(state.staff):
		var st: Staff = state.staff[sid]
		if st.assigned_project_id != project_id:
			continue
		if st.seat_index >= 0 and equipment_at_seat(state, st.company_id, st.seat_index) != -1:
			out.append(sid)
	return out


## True when the three sliders of the stage add up to 1.0 (10000 bp). Accepts typed or JSON arrays.
static func stage_sliders_ok(focus: Array, stage: int) -> bool:
	return int(focus[stage * 3]) + int(focus[stage * 3 + 1]) + int(focus[stage * 3 + 2]) == Fixed.ONE_BP


static func stage_count_of_kind(kind: Project.Kind) -> int:
	return 1 if kind == Project.Kind.ENGINE else 3


static func stage_count(p: Project) -> int:
	return stage_count_of_kind(p.kind)


@warning_ignore("integer_division")
static func stage_weeks(p: Project, content: ContentDB, _tuning: TuningDef) -> int:
	if p.kind == Project.Kind.ENGINE:
		var total: int = 0
		for f: StringName in p.features:
			if content.engine_features.has(f):
				total += content.engine_features[f].dev_weeks
		return maxi(1, total)
	if not content.sizes.has(p.size_id):
		return 1
	return maxi(1, content.sizes[p.size_id].base_weeks / 3)


static func min_staff(p: Project, content: ContentDB, tuning: TuningDef) -> int:
	if p.kind == Project.Kind.ENGINE:
		return tuning.engine_min_staff
	if not content.sizes.has(p.size_id):
		return 1
	return content.sizes[p.size_id].min_staff


static func engine_features(state: GameState, content: ContentDB, engine_id: int, licensed_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	if state.engines.has(engine_id):
		out.append_array(state.engines[engine_id].features)
	elif content.licensed_engines.has(licensed_id):
		out.append_array(content.licensed_engines[licensed_id].features)
	return out


## The licensed engine def a project uses, or null when it uses a built engine or none is found.
static func project_licensed_engine(state: GameState, content: ContentDB, p: Project) -> LicensedEngineDef:
	if state.engines.has(p.engine_id):
		return null
	return content.licensed_engines.get(p.config.get(&"engine", &""), null)


static func engine_tech_cap(state: GameState, content: ContentDB, p: Project) -> int:
	if state.engines.has(p.engine_id):
		return state.engines[p.engine_id].tech_cap
	var def: LicensedEngineDef = project_licensed_engine(state, content, p)
	return def.tech_cap if def != null else 0


## The company's ENGINE_LICENSE contract for a licensed engine (lowest id wins), or null.
static func engine_license_contract(state: GameState, company_id: int, licensed_id: StringName) -> Contract:
	for cid: int in state.sorted_ids(state.contracts):
		var c: Contract = state.contracts[cid]
		if c.kind == Contract.Kind.ENGINE_LICENSE and c.party_a == company_id and c.deliverable == licensed_id:
			return c
	return null


## Ruling A7 / A11: free engines need no contract; others need an ENGINE_LICENSE contract.
static func licensed_engine_available(state: GameState, content: ContentDB, company_id: int, licensed_id: StringName, week: int, tuning: TuningDef) -> bool:
	if not content.licensed_engines.has(licensed_id):
		return false
	var def: LicensedEngineDef = content.licensed_engines[licensed_id]
	var year: int = Calendar.year(week, tuning)
	if year < def.year_from or year > def.year_to:
		return false
	if def.fee == 0:
		return true
	return engine_license_contract(state, company_id, licensed_id) != null


## Ruling B12: the lowest-id VENDOR company, or -1.
static func first_vendor(state: GameState) -> int:
	for id: int in state.sorted_ids(state.companies):
		if state.companies[id].kind == Company.Kind.VENDOR:
			return id
	return -1
