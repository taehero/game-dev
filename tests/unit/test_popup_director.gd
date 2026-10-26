extends GutTest

const KIND: StringName = &"pevent_fx_a"

var _host: Control
var _queue: PopupQueue
var _director: PopupDirector
var _pauses: int = 0
var _resumes: int = 0
var _pid: int = -1
var _did: int = -1


func before_each() -> void:
	_pauses = 0
	_resumes = 0
	var ev := Fixtures.pevent(KIND, {&"bugs": 3}, {}, {&"hype": -2})
	var content: ContentDB = Fixtures.content_plus([ev] as Array[Resource])
	ContentDB.use(content)
	var s: GameState = Fixtures.new_state(3)
	_pid = Fixtures.add_project(s, {"phase": Project.Phase.POLISH, "bugs": 30, "title": "Mine"})
	_did = _add_decision(s)
	GameRunner.session = GameSession.new(s, Fixtures.tuning())
	GameRunner.session.speed = 0
	_host = Control.new()
	_host.size = Vector2(640, 360)
	add_child_autofree(_host)
	_queue = PopupQueue.new(_host, func() -> void: _pauses += 1, func() -> void: _resumes += 1)
	_director = PopupDirector.new()
	add_child_autofree(_director)
	_director.setup(_queue, content, Rect2(0, 0, 640, 360))


func after_each() -> void:
	GameRunner.session = null
	ContentDB.use(Fixtures.content())


func _add_decision(s: GameState) -> int:
	var d := Decision.new()
	d.id = s.alloc_id()
	d.kind = KIND
	d.related_ids.assign([_pid])
	d.deadline_week = s.week + 4
	d.option_keys.assign([&"ui.event.opt_a", &"ui.event.opt_b", &"ui.event.opt_c"])
	s.pending_decisions.append(d)
	return d.id


func _body_script(popup: PopupCard) -> Object:
	return popup.body().get_child(0)


func test_review_published_queues_review_popup() -> void:
	EventBus.dispatch(&"review_published", {"project_id": _pid})
	assert_not_null(_queue.current())
	assert_true(_body_script(_queue.current()) is ReviewView)


func test_ai_project_review_ignored() -> void:
	var s: GameState = GameRunner.session.state
	var ai: int = Fixtures.add_project(s, {"phase": Project.Phase.RELEASED})
	s.projects[ai].company_id = s.player_company_id + 999
	EventBus.dispatch(&"review_published", {"project_id": ai})
	assert_null(_queue.current())


func test_decision_required_for_event_queues_event_popup() -> void:
	EventBus.dispatch(&"decision_required", {"decision_id": _did})
	assert_not_null(_queue.current())
	assert_true(_body_script(_queue.current()) is EventView)
	EventBus.dispatch(&"decision_required", {"decision_id": _did})
	assert_eq(_queue.pending_count(), 0)


func test_every_pending_event_is_queued_not_only_the_payload_one() -> void:
	var second: int = _add_decision(GameRunner.session.state)
	EventBus.dispatch(&"decision_required", {"decision_id": second})
	assert_not_null(_queue.current())
	assert_eq(_queue.pending_count(), 1)


func test_other_decision_kind_ignored() -> void:
	var s: GameState = GameRunner.session.state
	s.pending_decisions.clear()
	var d := Decision.new()
	d.id = s.alloc_id()
	d.kind = &"contract_offer"
	s.pending_decisions.append(d)
	EventBus.dispatch(&"decision_required", {"decision_id": d.id})
	assert_null(_queue.current())


func test_polish_phase_offers_bug_hunt() -> void:
	EventBus.dispatch(&"project_phase_changed", {"project_id": _pid, "phase": "POLISH"})
	assert_true(_body_script(_queue.current()) is BugHuntOffer)
	_queue.current().close()
	EventBus.dispatch(&"project_phase_changed", {"project_id": _pid, "phase": "POLISH"})
	assert_null(_queue.current(), "offered once per game")


func test_hunt_request_opens_bug_hunt() -> void:
	_director.show_bug_hunt_offer(_pid)
	(_body_script(_queue.current()) as BugHuntOffer).hunt_requested.emit(_pid)
	_queue.current().close()
	assert_true(_body_script(_queue.current()) is BugHuntView)


func test_review_and_event_in_one_batch_queue_in_order() -> void:
	EventBus.dispatch(&"review_published", {"project_id": _pid})
	EventBus.dispatch(&"decision_required", {"decision_id": _did})
	assert_true(_body_script(_queue.current()) is ReviewView)
	assert_eq(_queue.pending_count(), 1)
	_queue.current().close()
	assert_true(_body_script(_queue.current()) is EventView)
	assert_eq(_pauses, 1)


func test_game_loaded_requeues_pending_events() -> void:
	EventBus.dispatch(&"review_published", {"project_id": _pid})
	EventBus.dispatch(&"decision_required", {"decision_id": _did})
	var s: GameState = Fixtures.new_state(4)
	_pid = Fixtures.add_project(s, {"phase": Project.Phase.POLISH})
	_add_decision(s)
	GameRunner.session = GameSession.new(s, Fixtures.tuning())
	EventBus.dispatch(&"game_loaded", {})
	assert_true(_body_script(_queue.current()) is EventView)
	assert_eq(_queue.pending_count(), 0)
