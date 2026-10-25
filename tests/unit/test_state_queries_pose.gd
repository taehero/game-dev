extends GutTest

var t := Fixtures.tuning()

func _prod(state: GameState, crunch: bool) -> int:
	var pid := Fixtures.add_project(state)
	state.projects[pid].phase = Project.Phase.PRODUCTION
	state.projects[pid].crunch = crunch
	return pid

func test_unassigned_staff_is_idle() -> void:
	var s := Fixtures.new_state(1)
	var id := Fixtures.add_staff(s)
	assert_eq(StateQueries.staff_pose(s, id, t), StateQueries.StaffPose.IDLE)

func test_staff_on_production_project_is_working() -> void:
	var s := Fixtures.new_state(1)
	var id := Fixtures.add_staff(s, {"assigned_project_id": _prod(s, false)})
	assert_eq(StateQueries.staff_pose(s, id, t), StateQueries.StaffPose.WORKING)

func test_polish_counts_as_working() -> void:
	var s := Fixtures.new_state(1)
	var pid := _prod(s, false)
	s.projects[pid].phase = Project.Phase.POLISH
	var id := Fixtures.add_staff(s, {"assigned_project_id": pid})
	assert_eq(StateQueries.staff_pose(s, id, t), StateQueries.StaffPose.WORKING)

func test_crunch_project_gives_crunching() -> void:
	var s := Fixtures.new_state(1)
	var id := Fixtures.add_staff(s, {"assigned_project_id": _prod(s, true)})
	assert_eq(StateQueries.staff_pose(s, id, t), StateQueries.StaffPose.CRUNCHING)

func test_burnout_at_threshold_overrides_crunch() -> void:
	var s := Fixtures.new_state(1)
	var id := Fixtures.add_staff(s, {"assigned_project_id": _prod(s, true), "burnout": t.resign_burnout_threshold})
	assert_eq(StateQueries.staff_pose(s, id, t), StateQueries.StaffPose.BURNED_OUT)

func test_released_project_gives_idle() -> void:
	var s := Fixtures.new_state(1)
	var pid := _prod(s, false)
	s.projects[pid].phase = Project.Phase.RELEASED
	var id := Fixtures.add_staff(s, {"assigned_project_id": pid})
	assert_eq(StateQueries.staff_pose(s, id, t), StateQueries.StaffPose.IDLE)

func test_dangling_project_id_and_missing_staff_are_idle() -> void:
	var s := Fixtures.new_state(1)
	var id := Fixtures.add_staff(s, {"assigned_project_id": 999})
	assert_eq(StateQueries.staff_pose(s, id, t), StateQueries.StaffPose.IDLE)
	assert_eq(StateQueries.staff_pose(s, 12345, t), StateQueries.StaffPose.IDLE)
