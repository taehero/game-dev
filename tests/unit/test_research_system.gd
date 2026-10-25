extends GutTest


func test_research_points_from_last_week_points() -> void:
	var s := Fixtures.new_state(1)
	s.staff[s.owner_staff_id()].week_points = {&"design": 300, &"tech": 200}
	ResearchSystem.tick(TickContext.new(s, Fixtures.tuning()))
	assert_eq(s.companies[1].research_points, 50)
