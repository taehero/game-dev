extends GutTest


func _ctx(s: GameState, week: int) -> TickContext:
	s.week = week
	return TickContext.new(s, Fixtures.tuning())


func _owner(s: GameState) -> Staff:
	return s.staff[s.owner.staff_id]


func test_xp_from_owner_points() -> void:
	var s := Fixtures.new_state(1)
	_owner(s).week_points = {&"design": 600, &"tech": 400}
	s.owner.xp = 2500
	OwnerSystem.tick(_ctx(s, 1))
	assert_eq(s.owner.xp, 3500)
	assert_eq(s.owner.skill_points, 1)


func test_xp_from_release_once() -> void:
	var s := Fixtures.new_state(1)
	var pid: int = Fixtures.add_project(s, {"phase": Project.Phase.RELEASED})
	OwnerSystem.tick(_ctx(s, 1))
	assert_eq(s.owner.xp, 1500)
	s.projects[pid].phase = Project.Phase.LIVE
	s.projects[pid].weekly_units = [10]
	OwnerSystem.tick(_ctx(s, 2))
	assert_eq(s.owner.xp, 1500)


func test_neglect_monthly() -> void:
	var s := Fixtures.new_state(1)
	var ids: Array[int] = []
	for i: int in 4:
		ids.append(Fixtures.add_staff(s, {"morale": 70}))
	s.owner.focus_dev_bp = 8000
	OwnerSystem.tick(_ctx(s, 4))
	assert_eq(s.staff[ids[0]].morale, 65)
	OwnerSystem.tick(_ctx(s, 5))
	assert_eq(s.staff[ids[0]].morale, 65)
	s.owner.focus_dev_bp = 7000
	OwnerSystem.tick(_ctx(s, 8))
	assert_eq(s.staff[ids[0]].morale, 65)
	s.owner.focus_dev_bp = 8000
	s.staff[ids[3]].is_owner = false
	Removal.remove_staff(s, ids[3])
	OwnerSystem.tick(_ctx(s, 12))
	assert_eq(s.staff[ids[0]].morale, 65)
