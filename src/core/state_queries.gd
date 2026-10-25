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
