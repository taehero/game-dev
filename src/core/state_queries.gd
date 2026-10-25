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
