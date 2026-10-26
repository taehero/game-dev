extends GutTest


func test_project_round_trip_keeps_event_fields() -> void:
	var state: GameState = Fixtures.new_state(1)
	var pid: int = Fixtures.add_project(state, {"event_ids": [&"pevent_fx_a"], "bug_hunt_done": true})
	var d: Dictionary = Fixtures.json_round_trip(state.to_dict())
	assert_true(StateValidator.validate(d))
	var back: GameState = GameState.from_dict(d)
	assert_eq(back.projects[pid].event_ids, [&"pevent_fx_a"] as Array[StringName])
	assert_true(back.projects[pid].bug_hunt_done)


func test_validator_rejects_non_string_event_id() -> void:
	var state: GameState = Fixtures.new_state(1)
	var pid: int = Fixtures.add_project(state)
	var d: Dictionary = Fixtures.json_round_trip(state.to_dict())
	assert_true(StateValidator.validate(d))
	var pd: Dictionary = d["projects"][str(pid)]
	pd["event_ids"] = [5]
	assert_false(StateValidator.validate(d))


func test_missing_refs_flags_unknown_event_in_project_and_decision() -> void:
	var state: GameState = Fixtures.new_state(1)
	Fixtures.add_project(state, {"event_ids": [&"pevent_fx_gone"]})
	var dec := Decision.new()
	dec.id = state.alloc_id()
	dec.kind = &"pevent_fx_gone"
	state.pending_decisions.append(dec)
	assert_eq(ContentDB.active().missing_refs(state).size(), 2)


func test_missing_refs_ignores_other_decision_kinds() -> void:
	var state: GameState = Fixtures.new_state(1)
	var dec := Decision.new()
	dec.id = state.alloc_id()
	dec.kind = &"raise_request"
	state.pending_decisions.append(dec)
	assert_eq(ContentDB.active().missing_refs(state).size(), 0)
