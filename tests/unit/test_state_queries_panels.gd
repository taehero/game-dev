extends GutTest

var _t: TuningDef = Fixtures.tuning()


func after_each() -> void:
	ContentDB.use(Fixtures.content())


func test_project_detail_flags_production_and_polish() -> void:
	var s := Fixtures.new_state(1)
	var c := Fixtures.content()
	var pid: int = Fixtures.add_project(s, {"bugs": 3})
	var d: Dictionary = StateQueries.project_detail(s, pid)
	assert_eq(d["id"], pid)
	assert_eq(d["kind"], Project.Kind.GAME)
	assert_eq(d["phase"], Project.Phase.PRODUCTION)
	assert_eq(d["stage_index"], 0)
	assert_eq(d["title"], s.projects[pid].title)
	assert_true(d["can_edit_sliders"])
	assert_false(d["can_release"])
	assert_false(d["can_bug_hunt"])
	d["focus"][0] = 1
	assert_ne(s.projects[pid].focus[0], 1, "focus is a copy")
	var p: Project = s.projects[pid]
	p.phase = Project.Phase.POLISH
	d = StateQueries.project_detail(s, pid)
	assert_false(d["can_edit_sliders"])
	assert_true(d["can_release"])
	assert_true(d["can_bug_hunt"])
	p.bug_hunt_done = true
	assert_false(StateQueries.project_detail(s, pid)["can_bug_hunt"])
	p.bug_hunt_done = false
	p.bugs = 0
	assert_false(StateQueries.project_detail(s, pid)["can_bug_hunt"])
	assert_not_null(c)
	assert_eq(StateQueries.project_detail(s, 9999), {})


func test_project_detail_engine_has_no_game_flags() -> void:
	var s := Fixtures.new_state(1)
	var eid: int = Fixtures.add_project(s, {"kind": Project.Kind.ENGINE, "bugs": 2})
	var d: Dictionary = StateQueries.project_detail(s, eid)
	assert_eq(d["kind"], Project.Kind.ENGINE)
	assert_false(d["can_edit_sliders"])
	assert_false(d["can_release"])
	assert_false(d["can_bug_hunt"])
	s.projects[eid].phase = Project.Phase.POLISH
	assert_false(StateQueries.project_detail(s, eid)["can_release"])


func test_past_games_order_and_keys() -> void:
	var s := Fixtures.new_state(1)
	var a: int = Fixtures.add_project(s, {"phase": Project.Phase.RELEASED, "release_week": 10, "weekly_units": [4, 7]})
	var b: int = Fixtures.add_project(s, {"phase": Project.Phase.LIVE, "release_week": 10})
	var c: int = Fixtures.add_project(s, {"phase": Project.Phase.RETIRED, "release_week": 20, "user_score": 77, "units_sold": 5, "revenue": 90})
	Fixtures.add_project(s, {"phase": Project.Phase.POLISH})
	Fixtures.add_project(s, {"kind": Project.Kind.ENGINE, "phase": Project.Phase.RELEASED, "release_week": 30})
	var rows: Array[Dictionary] = StateQueries.past_games(s)
	assert_eq(rows.size(), 3)
	assert_eq(rows[0]["id"], c)
	assert_eq(rows[1]["id"], b)
	assert_eq(rows[2]["id"], a)
	assert_eq(rows[0]["user_score"], 77)
	assert_eq(rows[0]["units_sold"], 5)
	assert_eq(rows[0]["revenue"], 90)
	assert_eq(rows[0]["last_units"], 0)
	assert_eq(rows[2]["last_units"], 7)
	assert_eq(rows[2]["release_week"], 10)
	assert_eq(rows[2]["phase"], Project.Phase.RELEASED)
	assert_true(rows[2].has("title"))


func test_review_view_keys_and_order() -> void:
	var s := Fixtures.new_state(1)
	var pid: int = Fixtures.add_project(s, {"user_score": 66})
	for o: StringName in [&"outlet_fx_b", &"outlet_fx_a"]:
		var r := ReviewResult.new()
		r.outlet_id = o
		r.score_x10 = 70
		r.strength_key = &"review.strong.generic"
		r.weakness_key = &"review.weak.generic"
		s.projects[pid].review_results.append(r)
	var v: Dictionary = StateQueries.review_view(s, pid)
	assert_eq(v["title"], s.projects[pid].title)
	assert_eq(v["user_score"], 66)
	assert_eq(v["genre_id"], &"genre_fx_action")
	assert_eq(v["platform_id"], &"platform_fx_micro")
	var reviews: Array = v["reviews"]
	assert_eq(reviews.size(), 2)
	assert_eq(reviews[0]["outlet_id"], &"outlet_fx_b")
	assert_eq(reviews[1]["outlet_id"], &"outlet_fx_a")
	assert_eq(reviews[0]["score_x10"], 70)
	assert_eq(reviews[0]["strength_key"], &"review.strong.generic")
	assert_eq(reviews[0]["weakness_key"], &"review.weak.generic")
	assert_eq(StateQueries.review_view(s, 9999), {})


func test_sales_series() -> void:
	var s := Fixtures.new_state(1)
	var pid: int = Fixtures.add_project(s, {"weekly_units": [3, 5, 8]})
	assert_eq(StateQueries.sales_series(s, pid), [3, 5, 8] as Array[int])
	assert_eq(StateQueries.sales_series(s, 9999), [] as Array[int])


func test_staff_rows_seat_and_computer() -> void:
	var s := Fixtures.new_state(1)
	var worker: int = Fixtures.add_staff(s, {"seat_index": 1, "name": "Zed"})
	var rows: Array[Dictionary] = StateQueries.staff_rows(s)
	var by_id: Dictionary = {}
	for r: Dictionary in rows:
		by_id[r["id"]] = r
	assert_eq(rows.size(), s.staff_of(s.player_company_id).size())
	var owner_row: Dictionary = {}
	for r: Dictionary in rows:
		if r["is_owner"]:
			owner_row = r
	assert_false(owner_row.is_empty())
	assert_true(owner_row["has_computer"])
	assert_false(by_id[worker]["has_computer"])
	assert_eq(by_id[worker]["name"], "Zed")
	assert_eq(by_id[worker]["seat_index"], 1)
	assert_eq(by_id[worker]["salary"], 500)
	assert_eq(by_id[worker]["project_id"], -1)
	assert_eq(by_id[worker]["skills"][&"design"], 20)
	by_id[worker]["skills"][&"design"] = 99
	assert_eq(s.staff[worker].skills[&"design"], 20, "skills is a copy")
	for k: String in ["morale", "burnout"]:
		assert_true(by_id[worker].has(k))


func test_platform_rows_status_by_week() -> void:
	var s := Fixtures.new_state(1)
	var c := Fixtures.content()
	var rows: Array[Dictionary] = StateQueries.platform_rows(s, c, _t)
	assert_eq(rows[0]["id"], &"platform_fx_console")
	assert_eq(rows[1]["id"], &"platform_fx_micro")
	assert_eq(rows[0]["status"], GameRules.PlatformStatus.UNANNOUNCED)
	assert_eq(rows[0]["dev_kit_cost"], 3000)
	assert_false(rows[0]["owned"])
	assert_true(rows[1]["owned"])
	assert_eq(rows[0]["name_key"], &"fx.platform_fx_console")
	s.week = 30
	rows = StateQueries.platform_rows(s, c, _t)
	assert_eq(rows[0]["status"], GameRules.PlatformStatus.ON_SALE)
	assert_eq(rows[0]["install_base"], PlatformSystem.install_base(c.platforms[&"platform_fx_console"], 30, _t))


func test_research_rows_availability() -> void:
	var s := Fixtures.new_state(1)
	var c := Fixtures.content()
	var by_id: Dictionary = {}
	var rows: Array[Dictionary] = StateQueries.research_rows(s, c)
	for r: Dictionary in rows:
		by_id[r["id"]] = r
	assert_eq(rows[0]["id"], &"research_fx_adventure")
	assert_false(by_id[&"research_fx_adventure"]["available"])
	assert_true(by_id[&"research_fx_scroll"]["available"])
	assert_eq(by_id[&"research_fx_scroll"]["cost_rp"], 50)
	assert_eq(by_id[&"research_fx_adventure"]["prerequisites"], [&"research_fx_scroll"] as Array[StringName])
	s.companies[s.player_company_id].unlocked.append(&"research_fx_scroll")
	by_id.clear()
	for r: Dictionary in StateQueries.research_rows(s, c):
		by_id[r["id"]] = r
	assert_true(by_id[&"research_fx_scroll"]["done"])
	assert_false(by_id[&"research_fx_scroll"]["available"])
	assert_true(by_id[&"research_fx_adventure"]["available"])


func test_finance_view_sums() -> void:
	var s := Fixtures.new_state(1)
	var comp: Company = s.companies[s.player_company_id]
	var salaries: int = 0
	for sid: int in s.staff_of(s.player_company_id):
		salaries += s.staff[sid].salary
	Fixtures.add_staff(s, {"salary": 700})
	Fixtures.add_project(s, {"revenue": 100})
	Fixtures.add_project(s, {"revenue": 50})
	Fixtures.add_project(s, {"kind": Project.Kind.ENGINE, "revenue": 999})
	comp.research_points = 12
	var v: Dictionary = StateQueries.finance_view(s)
	assert_eq(v["money"], comp.money)
	assert_eq(v["monthly_salaries"], salaries + 700)
	assert_eq(v["research_points"], 12)
	assert_eq(v["total_revenue"], 150)


func test_concept_options() -> void:
	var s := Fixtures.new_state(1)
	var c := Fixtures.content()
	var o: Dictionary = StateQueries.concept_options(s, c, _t)
	assert_eq(o["genres"], [&"genre_fx_action"] as Array[StringName])
	assert_eq(o["topics"], [&"topic_fx_space"] as Array[StringName])
	assert_eq(o["sizes"], [&"size_small"] as Array[StringName])
	assert_eq(o["platforms"], [&"platform_fx_micro"] as Array[StringName])
	assert_eq(o["kitless_on_sale"], 0)
	s.week = 30
	o = StateQueries.concept_options(s, c, _t)
	assert_eq(o["platforms"], [&"platform_fx_micro"] as Array[StringName], "console kitless")
	assert_eq(o["kitless_on_sale"], 1)
	s.week = 25
	s.companies[s.player_company_id].dev_kits.append(&"platform_fx_console")
	o = StateQueries.concept_options(s, c, _t)
	assert_eq(o["platforms"], [&"platform_fx_console", &"platform_fx_micro"] as Array[StringName])
	assert_eq(o["kitless_on_sale"], 0)


func test_concept_options_engines() -> void:
	var s := Fixtures.new_state(1)
	var c := Fixtures.content()
	var built: int = Fixtures.add_engine(s, {"name": "Mine"})
	var o: Dictionary = StateQueries.concept_options(s, c, _t)
	var engines: Array = o["engines"]
	assert_eq(engines.size(), 2)
	assert_eq(engines[0]["choice_id"], StringName("built_%d" % built))
	assert_eq(engines[0]["engine_id"], built)
	assert_eq(engines[0]["licensed_id"], &"")
	assert_eq(engines[0]["name"], "Mine")
	assert_eq(engines[0]["name_key"], &"")
	assert_eq(engines[0]["tech_cap"], 35)
	assert_eq(engines[1]["choice_id"], &"lic_engine_homebrew")
	assert_eq(engines[1]["engine_id"], -1)
	assert_eq(engines[1]["licensed_id"], &"lic_engine_homebrew")
	assert_eq(engines[1]["name"], "")
	assert_eq(engines[1]["name_key"], &"fx.lic_engine_homebrew")
	assert_eq(engines[1]["tech_cap"], 40)
	for e: Dictionary in engines:
		assert_ne(e["licensed_id"], &"lic_engine_fx_pro", "no licence contract")


func test_usable_features() -> void:
	var s := Fixtures.new_state(1)
	var c := Fixtures.content()
	var eng: int = Fixtures.add_engine(s, {"features": [&"feature_fx_scroll", &"feature_fx_save"]})
	assert_eq(StateQueries.usable_features(s, c, eng, &""), [&"feature_fx_save"] as Array[StringName])
	s.companies[s.player_company_id].unlocked.append(&"research_fx_scroll")
	assert_eq(StateQueries.usable_features(s, c, eng, &""), [&"feature_fx_save", &"feature_fx_scroll"] as Array[StringName])
	var plain: int = Fixtures.add_engine(s)
	assert_eq(StateQueries.usable_features(s, c, plain, &""), [&"feature_fx_save"] as Array[StringName])
	assert_eq(StateQueries.usable_features(s, c, -1, &"lic_engine_homebrew"), [&"feature_fx_save"] as Array[StringName])


func test_engine_feature_options() -> void:
	var s := Fixtures.new_state(1)
	var c := Fixtures.content()
	assert_eq(StateQueries.engine_feature_options(s, c), [&"feature_fx_save"] as Array[StringName])
	s.companies[s.player_company_id].unlocked.append(&"research_fx_scroll")
	assert_eq(StateQueries.engine_feature_options(s, c), [&"feature_fx_save", &"feature_fx_scroll"] as Array[StringName])


func _event_content() -> ContentDB:
	var ev := Fixtures.pevent(&"pevent_fx_a", {&"tech": 5, &"bugs": -2, &"design": 0}, {&"hype": 3, &"design": 4, &"morale": -1})
	return Fixtures.content_plus([ev] as Array[Resource])


func test_pending_event_ids_and_event_view() -> void:
	var s := Fixtures.new_state(1)
	var c := _event_content()
	var pid: int = Fixtures.add_project(s)
	var other := Decision.new()
	other.id = s.alloc_id()
	other.kind = &"raise_request"
	s.pending_decisions.append(other)
	var d := Decision.new()
	d.id = s.alloc_id()
	d.kind = &"pevent_fx_a"
	d.related_ids = [pid] as Array[int]
	d.option_keys = [&"event.fx.option.1", &"event.fx.option.2"] as Array[StringName]
	s.pending_decisions.append(d)
	assert_eq(StateQueries.pending_event_ids(s, c), [d.id] as Array[int])
	var v: Dictionary = StateQueries.event_view(s, c, d.id)
	assert_eq(v["decision_id"], d.id)
	assert_eq(v["project_id"], pid)
	assert_eq(v["project_title"], s.projects[pid].title)
	assert_eq(v["title_key"], &"event.fx.title")
	assert_eq(v["body_key"], &"event.fx.body")
	assert_eq(v["option_keys"], d.option_keys)
	var fx: Array = v["effects"]
	assert_eq(fx.size(), 2)
	assert_eq(fx[0], {&"tech": 5, &"bugs": -2})
	assert_eq(fx[0].keys(), [&"tech", &"bugs"])
	assert_eq(fx[1].keys(), [&"design", &"hype", &"morale"])
	assert_eq(StateQueries.event_view(s, c, other.id), {})
	assert_eq(StateQueries.event_view(s, c, 9999), {})


func test_queries_do_not_mutate() -> void:
	var s := Fixtures.new_state(1)
	var c := _event_content()
	var pid: int = Fixtures.add_project(s, {"phase": Project.Phase.POLISH, "bugs": 2})
	Fixtures.add_engine(s)
	var d := Decision.new()
	d.id = s.alloc_id()
	d.kind = &"pevent_fx_a"
	d.related_ids = [pid] as Array[int]
	s.pending_decisions.append(d)
	var before: String = StateHash.of(s)
	StateQueries.project_detail(s, pid)
	StateQueries.past_games(s)
	StateQueries.review_view(s, pid)
	StateQueries.sales_series(s, pid)
	StateQueries.staff_rows(s)
	StateQueries.platform_rows(s, c, _t)
	StateQueries.research_rows(s, c)
	StateQueries.finance_view(s)
	StateQueries.concept_options(s, c, _t)
	StateQueries.usable_features(s, c, -1, &"lic_engine_homebrew")
	StateQueries.engine_feature_options(s, c)
	StateQueries.pending_event_ids(s, c)
	StateQueries.event_view(s, c, d.id)
	assert_eq(StateHash.of(s), before)


func test_is_player_game_staff_name_and_project_title() -> void:
	var s := Fixtures.new_state(1)
	var pid: int = Fixtures.add_project(s, {})
	assert_true(StateQueries.is_player_game(s, pid))
	assert_false(StateQueries.is_player_game(s, 9999))
	s.projects[pid].kind = Project.Kind.ENGINE
	assert_false(StateQueries.is_player_game(s, pid), "engines are not games")
	s.projects[pid].kind = Project.Kind.GAME
	s.projects[pid].company_id = s.player_company_id + 1
	assert_false(StateQueries.is_player_game(s, pid), "rival game")
	assert_eq(StateQueries.project_title(s, pid), s.projects[pid].title)
	assert_eq(StateQueries.project_title(s, 9999), "")
	var sid: int = s.staff_of(s.player_company_id)[0]
	assert_eq(StateQueries.staff_name(s, sid), s.staff[sid].name)
	assert_eq(StateQueries.staff_name(s, 9999), "")
	assert_eq(StateQueries.player_company_id(s), s.player_company_id)
