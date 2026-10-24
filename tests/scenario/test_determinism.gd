extends GutTest


func test_same_seed_same_hash_over_520_weeks() -> void:
	assert_eq(Scenario.run(Fixtures.new_state(7), Scenario.SCRIPT_BASIC, 520),
			Scenario.run(Fixtures.new_state(7), Scenario.SCRIPT_BASIC, 520))


func test_different_seed_different_hash() -> void:
	assert_ne(Scenario.run(Fixtures.new_state(7), Scenario.SCRIPT_BASIC, 520),
			Scenario.run(Fixtures.new_state(8), Scenario.SCRIPT_BASIC, 520))


## 0, 10 and 300 are command weeks, 13 is a quarter start, 260 is mid-run.
func test_save_load_continue_matches_uninterrupted_at_many_points() -> void:
	var full: String = Scenario.run(Fixtures.new_state(7), Scenario.SCRIPT_BASIC, 520)
	for save_week: int in [0, 10, 13, 260, 300]:
		var s: GameState = Fixtures.new_state(7)
		Scenario.advance(s, Scenario.SCRIPT_BASIC, save_week)
		var loaded: LoadResult = SaveService.deserialize(SaveService.serialize(s))
		assert_true(loaded.ok, "load at week %d" % save_week)
		Scenario.advance(loaded.state, Scenario.SCRIPT_BASIC, 520 - save_week)
		assert_eq(StateHash.of(loaded.state), full, "save at week %d" % save_week)


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
