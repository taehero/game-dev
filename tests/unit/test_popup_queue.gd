extends GutTest

const POPUP_SCENE: PackedScene = preload("res://src/ui/panels/popup_card.tscn")

var _host: Control
var _queue: PopupQueue
var _pauses: int = 0
var _resumes: int = 0
var _emptied: int = 0


func before_each() -> void:
	_pauses = 0
	_resumes = 0
	_emptied = 0
	_host = Control.new()
	add_child_autofree(_host)
	_queue = PopupQueue.new(_host, func() -> void: _pauses += 1, func() -> void: _resumes += 1)
	_queue.emptied.connect(func() -> void: _emptied += 1)


func _popup() -> PopupCard:
	return POPUP_SCENE.instantiate() as PopupCard


func test_push_when_idle_shows_and_pauses_once() -> void:
	var p: PopupCard = _popup()
	_queue.push(p)
	assert_true(p.is_inside_tree())
	assert_eq(_queue.current(), p)
	assert_eq(_pauses, 1)
	assert_eq(_queue.pending_count(), 0)


func test_two_pushes_show_one_at_a_time() -> void:
	var a: PopupCard = _popup()
	var b: PopupCard = _popup()
	_queue.push(a)
	_queue.push(b)
	assert_false(b.is_inside_tree())
	assert_eq(_queue.pending_count(), 1)
	assert_eq(_pauses, 1)


func test_resume_only_after_last_close() -> void:
	var a: PopupCard = _popup()
	var b: PopupCard = _popup()
	_queue.push(a)
	_queue.push(b)
	a.close()
	assert_eq(_queue.current(), b)
	assert_true(b.is_inside_tree())
	assert_eq(_resumes, 0)
	b.close()
	assert_eq(_resumes, 1)
	assert_eq(_emptied, 1)
	assert_null(_queue.current())


func test_clear_frees_current_and_pending() -> void:
	_queue.push(_popup())
	_queue.push(_popup())
	_queue.clear()
	await wait_frames(1)
	assert_eq(_host.get_child_count(), 0)
	assert_eq(_resumes, 1)
	assert_null(_queue.current())
	assert_eq(_queue.pending_count(), 0)


func test_clear_when_idle_does_not_resume() -> void:
	_queue.clear()
	assert_eq(_resumes, 0)
