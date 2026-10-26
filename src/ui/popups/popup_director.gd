class_name PopupDirector
extends Node
## Turns game events into popups and feeds them to the PopupQueue. UI-only: reads state, never writes it.

var _queue: PopupQueue
var _content: ContentDB
var _play_rect: Rect2
## Decision ids already queued or shown, and projects already offered the bug hunt (this game).
var _seen_events: Dictionary[int, bool] = {}
var _offered: Dictionary[int, bool] = {}


func setup(p_queue: PopupQueue, p_content: ContentDB, p_play_rect: Rect2) -> void:
	_queue = p_queue
	_content = p_content
	_play_rect = p_play_rect
	EventBus.review_published.connect(_on_review_published)
	EventBus.decision_required.connect(_on_decision_required)
	EventBus.project_phase_changed.connect(_on_phase_changed)
	EventBus.game_loaded.connect(_on_game_loaded)


func _exit_tree() -> void:
	if EventBus.review_published.is_connected(_on_review_published):
		EventBus.review_published.disconnect(_on_review_published)
		EventBus.decision_required.disconnect(_on_decision_required)
		EventBus.project_phase_changed.disconnect(_on_phase_changed)
		EventBus.game_loaded.disconnect(_on_game_loaded)


func show_new_game() -> void:
	_queue.push(ConceptWizard.popup(_content))


func show_new_engine() -> void:
	_queue.push(EnginePopup.popup(_content))


func show_sales(project_id: int) -> void:
	_queue.push(SalesView.popup(project_id, _content))


func show_bug_hunt_offer(project_id: int) -> void:
	if GameRunner.session == null:
		return
	var card: PopupCard = BugHuntOffer.popup(project_id, GameRunner.session.tuning)
	(card.body().get_child(0) as BugHuntOffer).hunt_requested.connect(show_bug_hunt)
	_queue.push(card)


## The seed is UI-only randomness: it only places the bugs on screen.
func show_bug_hunt(project_id: int) -> void:
	if GameRunner.session == null:
		return
	_queue.push(BugHuntView.popup(project_id, GameRunner.session.tuning, _play_rect, Time.get_ticks_usec()))


func _is_player_game(project_id: int) -> bool:
	if GameRunner.session == null:
		return false
	return StateQueries.is_player_game(GameRunner.session.state, project_id)


func _on_review_published(payload: Dictionary) -> void:
	var pid: int = int(payload.get("project_id", -1))
	if _is_player_game(pid):
		_queue.push(ReviewView.popup(pid, _content))


## The session reports only the newest decision, so queue every pending event not yet seen.
func _on_decision_required(_payload: Dictionary) -> void:
	_queue_pending_events()


func _queue_pending_events() -> void:
	if GameRunner.session == null:
		return
	for id: int in StateQueries.pending_event_ids(GameRunner.session.state, _content):
		if _seen_events.has(id):
			continue
		_seen_events[id] = true
		_queue.push(EventView.popup(id, _content))


func _on_phase_changed(payload: Dictionary) -> void:
	if String(payload.get("phase", "")) != "POLISH":
		return
	var pid: int = int(payload.get("project_id", -1))
	if _offered.has(pid) or not _is_player_game(pid):
		return
	_offered[pid] = true
	if GameRunner.session != null and StateQueries.project_detail(GameRunner.session.state, pid).get("can_bug_hunt", false):
		show_bug_hunt_offer(pid)


func _on_game_loaded(_payload: Dictionary) -> void:
	_queue.clear()
	_seen_events.clear()
	_offered.clear()
	_queue_pending_events()
