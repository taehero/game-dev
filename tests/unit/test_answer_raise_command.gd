extends GutTest


func _asked(kind: StringName = &"raise_request") -> Array:
	var s := Fixtures.new_state(1)
	var id: int = Fixtures.add_staff(s, {"salary": 300, "asking_raise": 700, "morale": 70})
	var d := Decision.new()
	d.id = s.alloc_id()
	d.kind = kind
	d.related_ids.assign([id])
	d.deadline_week = 9
	s.pending_decisions.append(d)
	s.week = 4
	return [s, id]


func _run(s: GameState, cmd: AnswerRaiseCommand) -> void:
	assert_true(cmd.validate(s, Fixtures.tuning()).ok)
	cmd.apply(TickContext.new(s, Fixtures.tuning()))


func test_accept_raise() -> void:
	var r := _asked()
	var s: GameState = r[0]
	_run(s, AnswerRaiseCommand.new(r[1], true))
	assert_eq(s.staff[r[1]].salary, 700)
	assert_eq(s.staff[r[1]].asking_raise, 0)
	assert_eq(s.staff[r[1]].last_raise_week, 4)
	assert_eq(s.staff[r[1]].level, Staff.Level.JUNIOR)
	assert_eq(s.pending_decisions.size(), 0)


func test_accept_promotion_levels_up() -> void:
	var r := _asked(&"promotion_request")
	_run(r[0], AnswerRaiseCommand.new(r[1], true))
	assert_eq(r[0].staff[r[1]].level, Staff.Level.MID)


func test_refuse_promotion_morale_minus_10() -> void:
	var r := _asked(&"promotion_request")
	_run(r[0], AnswerRaiseCommand.new(r[1], false))
	var st: Staff = r[0].staff[r[1]]
	assert_eq(st.morale, 60)
	assert_eq(st.raise_refusals, 1)
	assert_eq(st.salary, 300)


func test_answer_rejections() -> void:
	var r := _asked()
	var t := Fixtures.tuning()
	assert_eq(AnswerRaiseCommand.new(9999, true).validate(r[0], t).reason_key, &"error.staff_not_found")
	var other: int = Fixtures.add_staff(r[0])
	assert_eq(AnswerRaiseCommand.new(other, true).validate(r[0], t).reason_key, &"error.no_raise_pending")
