extends GutTest

var _t: TuningDef


func before_each() -> void:
	_t = Fixtures.tuning()


func _reviewed(s: GameState, score: int, overrides: Dictionary = {}) -> int:
	var rs: Array[ReviewResult] = []
	for i in 4:
		var r := ReviewResult.new()
		r.score_x10 = score
		rs.append(r)
	var o: Dictionary = {"phase": Project.Phase.LIVE, "release_week": 40, "review_results": rs}
	o.merge(overrides, true)
	return Fixtures.add_project(s, o)


func _enter(s: GameState, pid: int, aid: StringName = &"award_fx") -> CommandResult:
	var cmd := EnterAwardCommand.new(pid, aid)
	var r := cmd.validate(s, _t)
	if r.ok:
		cmd.apply(TickContext.new(s, _t))
	return r


func _ceremony(s: GameState) -> TickContext:
	var ctx := TickContext.new(s, _t)
	AwardsSystem.tick(ctx)
	return ctx


func _result_events(ctx: TickContext) -> Array:
	return ctx.events.filter(func(e: Dictionary) -> bool: return e["name"] == &"award_result")


func test_next_ceremony_week() -> void:
	var def: AwardDef = ContentDB.active().awards[&"award_fx"]
	assert_eq(AwardsSystem.next_ceremony_week(def, 45, _t), 50)
	assert_eq(AwardsSystem.next_ceremony_week(def, 50, _t), 102)
	assert_eq(AwardsSystem.next_ceremony_week(def, 51, _t), 102)


func test_enter_award_charges_fee() -> void:
	var s := Fixtures.new_state(1)
	s.week = 45
	var pid := _reviewed(s, 70)
	var ctx := TickContext.new(s, _t)
	var cmd := EnterAwardCommand.new(pid, &"award_fx")
	assert_true(cmd.validate(s, _t).ok)
	cmd.apply(ctx)
	assert_eq(s.companies[1].money, 19000)
	assert_eq(s.projects[pid].award_entry, &"award_fx")
	assert_eq(ctx.events[0]["name"], &"money_changed")
	assert_eq(ctx.events[1]["name"], &"project_changed")


func test_rejects_old_game() -> void:
	var s := Fixtures.new_state(1)
	s.week = 100
	var pid := _reviewed(s, 70, {"release_week": 45})
	assert_eq(_enter(s, pid).reason_key, &"error.award_not_eligible")


func test_rejects_dlc_and_unreleased() -> void:
	var s := Fixtures.new_state(1)
	s.week = 45
	var parent := _reviewed(s, 70)
	var dlc := _reviewed(s, 70, {"parent_id": parent})
	assert_eq(_enter(s, dlc).reason_key, &"error.award_not_eligible")
	var wip := Fixtures.add_project(s)
	assert_eq(_enter(s, wip).reason_key, &"error.award_not_eligible")


func test_rejects_unknown_award() -> void:
	var s := Fixtures.new_state(1)
	s.week = 45
	var pid := _reviewed(s, 70)
	assert_eq(_enter(s, pid, &"award_nope").reason_key, &"error.award_not_found")
	assert_eq(_enter(s, 9999).reason_key, &"error.project_not_found")


func test_rejects_double_entry() -> void:
	var s := Fixtures.new_state(1)
	s.week = 45
	var pid := _reviewed(s, 70)
	assert_true(_enter(s, pid).ok)
	assert_eq(_enter(s, pid).reason_key, &"error.award_entered")


func test_rejects_without_fee() -> void:
	var s := Fixtures.new_state(1)
	s.week = 45
	s.companies[1].money = 999
	var pid := _reviewed(s, 70)
	assert_eq(_enter(s, pid).reason_key, &"error.not_enough_money")


func test_ceremony_win() -> void:
	var s := Fixtures.new_state(1)
	s.week = 50
	var pid := _reviewed(s, 100, {"award_entry": &"award_fx"})
	var money: int = s.companies[1].money
	var fans: int = s.companies[1].fan_count
	var ctx := _ceremony(s)
	assert_eq(s.companies[1].money, money + 10000)
	assert_eq(s.companies[1].fan_count, fans + 500)
	assert_eq(s.companies[1].reputation, 5)
	assert_eq(s.companies[1].awards, [&"award_fx"] as Array[StringName])
	assert_eq(s.projects[pid].award_entry, &"")
	var ev := _result_events(ctx)
	assert_eq(ev.size(), 1)
	assert_true(ev[0]["payload"]["won"])
	assert_eq(ev[0]["payload"]["project_id"], pid)


func test_ceremony_loss() -> void:
	var s := Fixtures.new_state(1)
	s.week = 50
	_t.award_ai_score_min_x10 = 90
	var pid := _reviewed(s, 10, {"award_entry": &"award_fx"})
	var money: int = s.companies[1].money
	var ctx := _ceremony(s)
	assert_eq(s.companies[1].money, money)
	assert_true(s.companies[1].awards.is_empty())
	assert_eq(s.projects[pid].award_entry, &"")
	assert_false(_result_events(ctx)[0]["payload"]["won"])


func test_tie_goes_to_ai() -> void:
	var s := Fixtures.new_state(1)
	s.week = 50
	_t.award_bonus_max_x10 = 0
	_t.award_ai_score_min_x10 = 70
	_t.award_ai_score_max_x10 = 70
	_reviewed(s, 70, {"award_entry": &"award_fx"})
	var ctx := _ceremony(s)
	assert_false(_result_events(ctx)[0]["payload"]["won"])


func test_ceremony_without_eligible_entries_draws_no_rng() -> void:
	var s := Fixtures.new_state(1)
	s.week = 102
	var pid := _reviewed(s, 70, {"award_entry": &"award_fx", "release_week": 40})
	var before: int = s.rng.state
	var ctx := _ceremony(s)
	assert_eq(s.rng.state, before)
	assert_eq(s.projects[pid].award_entry, &"")
	var ev := _result_events(ctx)
	assert_eq(ev.size(), 1)
	assert_eq(ev[0]["payload"]["project_id"], -1)
	assert_false(ev[0]["payload"]["won"])


func test_no_entries_no_event() -> void:
	var s := Fixtures.new_state(1)
	s.week = 50
	_reviewed(s, 70)
	var before: int = s.rng.state
	var ctx := _ceremony(s)
	assert_eq(_result_events(ctx).size(), 0)
	assert_eq(s.rng.state, before)


func test_not_ceremony_week() -> void:
	var s := Fixtures.new_state(1)
	s.week = 49
	var pid := _reviewed(s, 70, {"award_entry": &"award_fx"})
	_ceremony(s)
	assert_eq(s.projects[pid].award_entry, &"award_fx")
