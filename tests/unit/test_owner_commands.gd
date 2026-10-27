extends GutTest


func _run(s: GameState, c: Command) -> CommandResult:
	var r: CommandResult = c.validate(s, Fixtures.tuning())
	if r.ok:
		c.apply(TickContext.new(s, Fixtures.tuning()))
	return r


func test_spend_point_coder() -> void:
	var s := Fixtures.new_state(1)
	s.owner.skill_points = 1
	s.staff[s.owner.staff_id].skills[&"tech"] = 30
	assert_true(_run(s, SpendSkillPointCommand.new(&"perk_coder")).ok)
	assert_eq(s.owner.perks[&"perk_coder"], 1)
	assert_eq(s.owner.skill_points, 0)
	assert_eq(s.staff[s.owner.staff_id].skills[&"tech"], 35)


func test_spend_rejections() -> void:
	var s := Fixtures.new_state(1)
	s.owner.skill_points = 1
	assert_eq(_run(s, SpendSkillPointCommand.new(&"perk_nope")).reason_key, &"error.perk_not_found")
	s.owner.skill_points = 0
	assert_eq(_run(s, SpendSkillPointCommand.new(&"perk_coder")).reason_key, &"error.no_skill_points")
	s.owner.skill_points = 1
	s.owner.perks[&"perk_coder"] = 3
	assert_eq(_run(s, SpendSkillPointCommand.new(&"perk_coder")).reason_key, &"error.perk_maxed")


func test_set_focus() -> void:
	var s := Fixtures.new_state(1)
	assert_true(_run(s, SetOwnerFocusCommand.new(5000)).ok)
	assert_eq(s.owner.focus_dev_bp, 5000)
	assert_eq(_run(s, SetOwnerFocusCommand.new(-1)).reason_key, &"error.invalid_focus")
	assert_eq(_run(s, SetOwnerFocusCommand.new(10001)).reason_key, &"error.invalid_focus")
