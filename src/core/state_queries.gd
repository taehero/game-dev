class_name StateQueries
extends RefCounted
## Read-only helpers for UI. Never mutates state.


static func date_text(state: GameState, t: TuningDef) -> String:
	return TranslationServer.translate("ui.hud.date").format({
		"year": Calendar.year(state.week, t),
		"week": Calendar.week_in_year(state.week, t) + 1,
	})


static func player_money(state: GameState) -> int:
	if not state.companies.has(state.player_company_id):
		return 0
	return state.companies[state.player_company_id].money


## Top-bar view: date text, player money, player fans, active project hype.
static func resource_view(state: GameState, t: TuningDef) -> Dictionary:
	var fans: int = 0
	if state.companies.has(state.player_company_id):
		fans = state.companies[state.player_company_id].fan_count
	var hype: int = 0
	var project_id: int = active_project_id(state)
	if state.projects.has(project_id):
		hype = state.projects[project_id].hype
	return {
		"date_text": date_text(state, t),
		"money": player_money(state),
		"fans": fans,
		"hype": hype,
	}


static func staff_count(state: GameState, company_id: int) -> int:
	return state.staff_of(company_id).size()


static func player_company_id(state: GameState) -> int:
	return state.player_company_id


enum StaffPose { IDLE, WORKING, CRUNCHING, BURNED_OUT }


## Ruling 6: burnout first, then crunch, then working, else idle.
static func staff_pose(state: GameState, staff_id: int, t: TuningDef) -> StaffPose:
	if not state.staff.has(staff_id):
		return StaffPose.IDLE
	var member: Staff = state.staff[staff_id]
	if member.burnout >= t.resign_burnout_threshold:
		return StaffPose.BURNED_OUT
	if not state.projects.has(member.assigned_project_id):
		return StaffPose.IDLE
	var project: Project = state.projects[member.assigned_project_id]
	if project.phase != Project.Phase.PRODUCTION and project.phase != Project.Phase.POLISH:
		return StaffPose.IDLE
	return StaffPose.CRUNCHING if project.crunch else StaffPose.WORKING


## Ruling 7: the player company's lowest-id project in PRODUCTION or POLISH, else -1.
static func active_project_id(state: GameState) -> int:
	for project_id: int in state.sorted_ids(state.projects):
		var project: Project = state.projects[project_id]
		if project.company_id != state.player_company_id:
			continue
		if project.phase == Project.Phase.PRODUCTION or project.phase == Project.Phase.POLISH:
			return project_id
	return -1


## Status-bar view of one project. `progress` is a percent (stage_progress is bp).
static func project_status(state: GameState, project_id: int) -> Dictionary:
	if not state.projects.has(project_id):
		return {}
	var project: Project = state.projects[project_id]
	return {
		"title": project.title,
		"topic_id": project.config.get(&"topic", &""),
		"genre_id": project.config.get(&"genre", &""),
		"stage": project.stage_index + 1,
		"stage_count": GameRules.stage_count(project),
		"progress": project.stage_progress / 100,
		"design": project.points.get(&"design", 0),
		"tech": project.points.get(&"tech", 0),
		"art": project.points.get(&"art", 0),
		"audio": project.points.get(&"audio", 0),
		"bugs": project.bugs,
		"hype": project.hype,
	}


## Id of the player company's office, or &"" if the company is missing.
static func player_office_id(state: GameState) -> StringName:
	if not state.companies.has(state.player_company_id):
		return &""
	return state.companies[state.player_company_id].office_id


## One view per seat 0 .. seats-1 (never more than desk_positions.size()). Bad seat data is
## ignored: out-of-range seats, storage (-1), other companies; the lowest id wins a shared seat.
static func seat_views(state: GameState, office: OfficeDef, equipment_defs: Dictionary[StringName, EquipmentDef], t: TuningDef) -> Array[SeatView]:
	var views: Array[SeatView] = []
	var count: int = mini(office.seats, office.desk_positions.size())
	var company_id: int = state.player_company_id
	for seat: int in count:
		var view := SeatView.new()
		view.seat_index = seat
		view.desk_cell = office.desk_positions[seat]
		views.append(view)
	for sid: int in state.sorted_ids(state.staff):
		var member: Staff = state.staff[sid]
		if member.company_id != company_id or member.seat_index < 0 or member.seat_index >= count:
			continue
		var seated: SeatView = views[member.seat_index]
		if seated.staff_id == -1:
			seated.staff_id = sid
	for view: SeatView in views:
		var eid: int = GameRules.equipment_at_seat(state, company_id, view.seat_index)
		if eid != -1:
			var def_id: StringName = state.equipment[eid].def_id
			if equipment_defs.has(def_id):
				view.computer_tier = equipment_defs[def_id].tier
		if view.staff_id != -1 and view.computer_tier > 0:
			view.pose = staff_pose(state, view.staff_id, t)
	return views


## Spec 6.6: label for a topic and genre pairing from the company's best released result.
static func combo_label_key(state: GameState, company_id: int, topic_id: StringName, genre_id: StringName, t: TuningDef) -> StringName:
	var best: int = -1
	for pid: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[pid]
		if p.company_id != company_id or p.kind != Project.Kind.GAME or p.phase < Project.Phase.RELEASED:
			continue
		if p.config.get(&"topic", &"") == topic_id and p.config.get(&"genre", &"") == genre_id:
			best = maxi(best, p.user_score)
	if best < 0:
		return &"ui.combo.unknown"
	if best >= t.combo_great_x10:
		return &"ui.combo.great"
	if best >= t.combo_good_x10:
		return &"ui.combo.good"
	if best >= t.combo_okay_x10:
		return &"ui.combo.okay"
	return &"ui.combo.bad"


# --- M2d panel views ---


static func _is_player_game(state: GameState, p: Project) -> bool:
	return p.company_id == state.player_company_id and p.kind == Project.Kind.GAME


## True when the project exists, belongs to the player and is a game (not an engine).
static func is_player_game(state: GameState, project_id: int) -> bool:
	return state.projects.has(project_id) and _is_player_game(state, state.projects[project_id])


## The staff member's name, or "" when the id is unknown.
static func staff_name(state: GameState, staff_id: int) -> String:
	if not state.staff.has(staff_id):
		return ""
	return state.staff[staff_id].name


## The project's title, or "" when the id is unknown.
static func project_title(state: GameState, project_id: int) -> String:
	if not state.projects.has(project_id):
		return ""
	return state.projects[project_id].title


static func _player_company(state: GameState) -> Company:
	return state.companies.get(state.player_company_id, null)


## Full project view for the project panel: status plus identity, phase and action flags.
static func project_detail(state: GameState, project_id: int) -> Dictionary:
	if not state.projects.has(project_id):
		return {}
	var p: Project = state.projects[project_id]
	var out: Dictionary = project_status(state, project_id)
	var is_game: bool = p.kind == Project.Kind.GAME
	var focus_copy: Array[int] = p.focus.duplicate()
	out["id"] = p.id
	out["kind"] = p.kind
	out["phase"] = p.phase
	out["stage_index"] = p.stage_index
	out["focus"] = focus_copy
	out["can_edit_sliders"] = is_game and p.phase == Project.Phase.PRODUCTION
	out["can_release"] = is_game and p.phase == Project.Phase.POLISH
	out["can_bug_hunt"] = is_game and p.phase == Project.Phase.POLISH and not p.bug_hunt_done and p.bugs > 0
	return out


## Released player games, newest release first (ties: higher id first).
static func past_games(state: GameState) -> Array[Dictionary]:
	var picked: Array[Project] = []
	for pid: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[pid]
		if _is_player_game(state, p) and p.phase >= Project.Phase.RELEASED:
			picked.append(p)
	picked.sort_custom(func(a: Project, b: Project) -> bool:
		if a.release_week != b.release_week:
			return a.release_week > b.release_week
		return a.id > b.id)
	var out: Array[Dictionary] = []
	for p: Project in picked:
		out.append({
			"id": p.id,
			"title": p.title,
			"phase": p.phase,
			"release_week": p.release_week,
			"user_score": p.user_score,
			"units_sold": p.units_sold,
			"revenue": p.revenue,
			"last_units": p.weekly_units.back() if not p.weekly_units.is_empty() else 0,
		})
	return out


static func review_view(state: GameState, project_id: int) -> Dictionary:
	if not state.projects.has(project_id):
		return {}
	var p: Project = state.projects[project_id]
	var reviews: Array[Dictionary] = []
	for r: ReviewResult in p.review_results:
		reviews.append({
			"outlet_id": r.outlet_id,
			"score_x10": r.score_x10,
			"strength_key": r.strength_key,
			"weakness_key": r.weakness_key,
		})
	return {
		"title": p.title,
		"user_score": p.user_score,
		"genre_id": p.config.get(&"genre", &""),
		"platform_id": p.config.get(&"platform", &""),
		"reviews": reviews,
	}


static func sales_series(state: GameState, project_id: int) -> Array[int]:
	var out: Array[int] = []
	if state.projects.has(project_id):
		out.assign(state.projects[project_id].weekly_units)
	return out


static func staff_rows(state: GameState) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for sid: int in state.staff_of(state.player_company_id):
		var m: Staff = state.staff[sid]
		var skills_copy: Dictionary[StringName, int] = m.skills.duplicate()
		out.append({
			"id": sid,
			"name": m.name,
			"is_owner": m.is_owner,
			"salary": m.salary,
			"skills": skills_copy,
			"morale": m.morale,
			"burnout": m.burnout,
			"seat_index": m.seat_index,
			"has_computer": GameRules.equipment_at_seat(state, state.player_company_id, m.seat_index) != -1,
			"project_id": m.assigned_project_id,
		})
	return out


static func platform_rows(state: GameState, content: ContentDB, t: TuningDef) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in GameState.sorted_names(content.platforms):
		var def: PlatformDef = content.platforms[id]
		out.append({
			"id": id,
			"name_key": def.name_key,
			"status": GameRules.platform_status(def, state.week),
			"dev_kit_cost": def.dev_kit_cost,
			"owned": GameRules.has_dev_kit(state, content, state.player_company_id, id),
			"install_base": PlatformSystem.install_base(def, state.week, t),
		})
	return out


static func research_rows(state: GameState, content: ContentDB) -> Array[Dictionary]:
	var done_list: Array[StringName] = []
	var company: Company = _player_company(state)
	if company != null:
		done_list = company.unlocked
	var out: Array[Dictionary] = []
	for id: StringName in GameState.sorted_names(content.research):
		var def: ResearchDef = content.research[id]
		var done: bool = done_list.has(id)
		var prereqs_met: bool = true
		for pre: StringName in def.prerequisites:
			if not done_list.has(pre):
				prereqs_met = false
		var prereq_copy: Array[StringName] = def.prerequisites.duplicate()
		out.append({
			"id": id,
			"name_key": def.name_key,
			"cost_rp": def.cost_rp,
			"done": done,
			"available": not done and prereqs_met,
			"prerequisites": prereq_copy,
		})
	return out


static func finance_view(state: GameState) -> Dictionary:
	var salaries: int = 0
	for sid: int in state.staff_of(state.player_company_id):
		salaries += state.staff[sid].salary
	var revenue: int = 0
	for pid: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[pid]
		if _is_player_game(state, p):
			revenue += p.revenue
	var company: Company = _player_company(state)
	return {
		"money": company.money if company != null else 0,
		"monthly_salaries": salaries,
		"research_points": company.research_points if company != null else 0,
		"total_revenue": revenue,
	}


static func _unlocked_ids(state: GameState, content: ContentDB, ids: Dictionary) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in GameState.sorted_names(ids):
		if GameRules.is_unlocked(state, content, state.player_company_id, id):
			out.append(id)
	return out


## Choices for the concept dialog. Built engines use choice_id "built_<id>"; licensed use their def id.
static func concept_options(state: GameState, content: ContentDB, t: TuningDef) -> Dictionary:
	var platforms: Array[StringName] = []
	var kitless: int = 0
	for id: StringName in GameState.sorted_names(content.platforms):
		if GameRules.platform_status(content.platforms[id], state.week) != GameRules.PlatformStatus.ON_SALE:
			continue
		if GameRules.has_dev_kit(state, content, state.player_company_id, id):
			platforms.append(id)
		else:
			kitless += 1
	var engines: Array[Dictionary] = []
	for eid: int in state.sorted_ids(state.engines):
		var e: GameEngine = state.engines[eid]
		if e.company_id != state.player_company_id:
			continue
		engines.append({
			"choice_id": StringName("built_%d" % eid),
			"engine_id": eid,
			"licensed_id": &"",
			"name": e.name,
			"name_key": &"",
			"tech_cap": e.tech_cap,
		})
	for lid: StringName in GameState.sorted_names(content.licensed_engines):
		if not GameRules.licensed_engine_available(state, content, state.player_company_id, lid, state.week, t):
			continue
		engines.append({
			"choice_id": lid,
			"engine_id": -1,
			"licensed_id": lid,
			"name": "",
			"name_key": content.licensed_engines[lid].name_key,
			"tech_cap": content.licensed_engines[lid].tech_cap,
		})
	return {
		"sizes": _unlocked_ids(state, content, content.sizes),
		"topics": _unlocked_ids(state, content, content.topics),
		"genres": _unlocked_ids(state, content, content.genres),
		"platforms": platforms,
		"kitless_on_sale": kitless,
		"engines": engines,
	}


static func usable_features(state: GameState, content: ContentDB, engine_id: int, licensed_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for f: StringName in GameRules.engine_features(state, content, engine_id, licensed_id):
		if GameRules.is_unlocked(state, content, state.player_company_id, f) and not out.has(f):
			out.append(f)
	out.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return out


static func engine_feature_options(state: GameState, content: ContentDB) -> Array[StringName]:
	return _unlocked_ids(state, content, content.engine_features)


static func pending_event_ids(state: GameState, content: ContentDB) -> Array[int]:
	var out: Array[int] = []
	for d: Decision in state.pending_decisions:
		if content.production_events.has(d.kind):
			out.append(d.id)
	out.sort()
	return out


static func event_view(state: GameState, content: ContentDB, decision_id: int) -> Dictionary:
	for d: Decision in state.pending_decisions:
		if d.id != decision_id:
			continue
		if not content.production_events.has(d.kind):
			return {}
		var def: ProductionEventDef = content.production_events[d.kind]
		var project_id: int = d.related_ids[0] if not d.related_ids.is_empty() else -1
		var title: String = state.projects[project_id].title if state.projects.has(project_id) else ""
		var effects: Array[Dictionary] = []
		for i: int in d.option_keys.size():
			var src: Dictionary[StringName, int] = def.option_effects(i)
			var fx: Dictionary = {}
			for k: StringName in ProductionEventDef.EFFECTS:
				if src.get(k, 0) != 0:
					fx[k] = src[k]
			effects.append(fx)
		var option_copy: Array[StringName] = d.option_keys.duplicate()
		return {
			"decision_id": d.id,
			"project_id": project_id,
			"project_title": title,
			"title_key": def.title_key,
			"body_key": def.body_key,
			"option_keys": option_copy,
			"effects": effects,
		}
	return {}


## Market salary for a staff member at their current level; 0 if missing.
static func market_salary(state: GameState, staff_id: int, t: TuningDef) -> int:
	if not state.staff.has(staff_id):
		return 0
	var s: Staff = state.staff[staff_id]
	return PeopleRules.market_salary(s.skills, int(s.level), ContentDB.active(), t)


static func monthly_costs(state: GameState) -> Dictionary:
	return MoneyRules.monthly_costs(state, ContentDB.active(), state.player_company_id)


static func available_credit(state: GameState, lender_id: int, t: TuningDef) -> int:
	return MoneyRules.available_credit(state, state.player_company_id, lender_id, t)


## {} or {"amount", "promotion", "deadline_week"} for a pending raise/promotion ask.
static func pending_ask(state: GameState, staff_id: int) -> Dictionary:
	var d: Decision = AnswerRaiseCommand.find_ask(state, staff_id)
	if d == null or not state.staff.has(staff_id):
		return {}
	return {
		"amount": state.staff[staff_id].asking_raise,
		"promotion": d.kind == &"promotion_request",
		"deadline_week": d.deadline_week,
	}
