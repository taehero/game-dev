extends GutTest


func test_same_seed_same_hash_over_520_weeks() -> void:
	assert_eq(Scenario.run(Fixtures.new_state(7), Scenario.SCRIPT_BASIC, 520),
			Scenario.run(Fixtures.new_state(7), Scenario.SCRIPT_BASIC, 520))


func test_different_seed_different_hash() -> void:
	assert_ne(Scenario.run(Fixtures.new_state(7), Scenario.SCRIPT_BASIC, 520),
			Scenario.run(Fixtures.new_state(8), Scenario.SCRIPT_BASIC, 520))


func test_save_at_260_load_continue_matches_uninterrupted() -> void:
	var full: String = Scenario.run(Fixtures.new_state(7), Scenario.SCRIPT_BASIC, 520)
	var s: GameState = Fixtures.new_state(7)
	Scenario.advance(s, Scenario.SCRIPT_BASIC, 260)
	var loaded: LoadResult = SaveService.deserialize(SaveService.serialize(s))
	assert_true(loaded.ok)
	Scenario.advance(loaded.state, Scenario.SCRIPT_BASIC, 260)
	assert_eq(StateHash.of(loaded.state), full)


func test_values_stay_in_range() -> void:
	var s: GameState = Fixtures.new_state(7)
	Scenario.advance(s, Scenario.SCRIPT_BASIC, 520)
	assert_eq(s.week, 520)
	assert_eq(s.staff.size(), 4)
	var tuning: TuningDef = Fixtures.tuning()
	assert_between(s.companies[s.player_company_id].reputation, 0, 100)
	assert_true(s.staff_of(s.player_company_id).size() <= tuning.max_staff_default)
	for id: int in s.sorted_ids(s.staff):
		var st: Staff = s.staff[id]
		for skill: StringName in st.skills:
			assert_between(st.skills[skill], tuning.hire_skill_min, tuning.hire_skill_max)
		assert_between(st.morale, 0, 100)
		assert_between(st.burnout, 0, 100)
