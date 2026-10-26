class_name PopupQueue
extends RefCounted
## Shows popups one at a time. Pauses once when it goes busy, resumes after the last closes.

signal emptied

var _host: Control
var _pause: Callable
var _resume: Callable
var _current: PopupCard = null
var _pending: Array[PopupCard] = []


func _init(p_host: Control, p_pause: Callable, p_resume: Callable) -> void:
	_host = p_host
	_pause = p_pause
	_resume = p_resume


func push(popup: PopupCard) -> void:
	if _current == null:
		_pause.call()
		_show(popup)
	else:
		_pending.append(popup)


func current() -> PopupCard:
	return _current


func pending_count() -> int:
	return _pending.size()


func clear() -> void:
	var was_busy: bool = _current != null
	for p: PopupCard in _pending:
		p.free()
	_pending.clear()
	if _current != null:
		if _current.closed.is_connected(_on_closed):
			_current.closed.disconnect(_on_closed)
		if is_instance_valid(_current):
			_current.queue_free()
		_current = null
	if was_busy:
		_resume.call()


func _show(popup: PopupCard) -> void:
	_current = popup
	popup.closed.connect(_on_closed, CONNECT_ONE_SHOT)
	_host.add_child(popup)


func _on_closed() -> void:
	_current = null
	if _pending.is_empty():
		_resume.call()
		emptied.emit()
	else:
		_show(_pending.pop_front())
