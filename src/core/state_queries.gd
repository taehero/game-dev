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


const STAGE_COUNT: int = 3


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
		"stage": project.stage_index + 1,
		"progress": project.stage_progress / 100,
		"design": project.points.get(&"design", 0),
		"tech": project.points.get(&"tech", 0),
		"art": project.points.get(&"art", 0),
		"audio": project.points.get(&"audio", 0),
		"bugs": project.bugs,
		"hype": project.hype,
	}
