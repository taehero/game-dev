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
