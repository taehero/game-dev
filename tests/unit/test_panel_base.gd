extends GutTest


class CountingPanel extends PanelBase:
	var refreshes: int = 0

	func refresh(_view: GameState, _t: TuningDef) -> void:
		refreshes += 1


func before_each() -> void:
	GameRunner.session = GameSession.new(Fixtures.new_state(1), Fixtures.tuning())


func after_each() -> void:
	GameRunner.session = null


func test_successful_submit_refreshes_and_refusal_does_not() -> void:
	var panel := CountingPanel.new()
	add_child_autofree(panel)
	var before: int = panel.refreshes
	assert_false(panel.submit(BuyDevKitCommand.new(-1, &"nope")))
	assert_eq(panel.refreshes, before, "refused submit does not refresh")
	assert_ne(panel.status_label().text, "")
	var cid: int = GameRunner.session.state.player_company_id
	assert_true(panel.submit(HireStaffCommand.new(cid, "Ada", GameRunner.session.tuning.hire_offer_salary)))
	assert_eq(panel.refreshes, before + 1, "accepted submit refreshes once")
