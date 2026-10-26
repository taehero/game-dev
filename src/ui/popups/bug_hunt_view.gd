class_name BugHuntView
extends VBoxContainer
## Real-time bug-hunt mini-game. UI-only randomness and floats; one command is sent at the end.

const CARD_SCENE: PackedScene = preload("res://src/ui/panels/popup_card.tscn")
const BUG_LIFETIME_S: float = 1.6
const EXTRA_SPAWNS: int = 4
const GRID_COLS: int = 8
const GRID_ROWS: int = 4
const BUG_SIZE := Vector2(28, 28)

var project_id: int = -1
var tuning: TuningDef
var play_rect: Rect2 = Rect2()
var rng_seed: int = 0

var _popup: PopupCard
var _rng := RandomNumberGenerator.new()
var _elapsed: float = 0.0
var _spawned: int = 0
var _total: int = 0
var _caught: int = 0
var _finished: bool = false
var _next_name: int = 0
var _time: Label
var _caught_label: Label
var _result: Label
var _ok: Button


static func popup(p_project_id: int, p_tuning: TuningDef, p_play_rect: Rect2, p_seed: int) -> PopupCard:
	var card: PopupCard = CARD_SCENE.instantiate()
	card.card_size = Vector2(220, 64)
	card.closable = false
	var dialog := BugHuntView.new()
	dialog.project_id = p_project_id
	dialog.tuning = p_tuning
	dialog.play_rect = p_play_rect
	dialog.rng_seed = p_seed
	dialog._popup = card
	card.body().add_child(dialog)
	card.open(TranslationServer.translate("ui.bughunt.title"))
	return card


func _ready() -> void:
	_rng.seed = rng_seed
	_total = tuning.bug_hunt_max_bugs + EXTRA_SPAWNS
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	add_child(row)
	_time = _label("Time", row)
	_caught_label = _label("Caught", row)
	_result = _label("Result", row)
	_result.visible = false
	_ok = Button.new()
	_ok.text = tr("ui.popup.ok")
	_ok.visible = false
	_ok.pressed.connect(_popup.close)
	_ok.name = "Ok"
	row.add_child(_ok)
	_ok.owner = self
	_ok.unique_name_in_owner = true
	_refresh()


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	for b: TextureButton in live_bugs():
		if _elapsed - float(b.get_meta(&"spawn_t")) >= BUG_LIFETIME_S:
			_remove(b)
	var interval: float = tuning.bug_hunt_seconds / float(_total)
	while _spawned < _total and _elapsed + 0.000001 >= float(_spawned) * interval:
		_spawn()
	_refresh()
	if _elapsed >= tuning.bug_hunt_seconds:
		finish()


func live_bugs() -> Array[TextureButton]:
	var out: Array[TextureButton] = []
	for c: Node in _popup.get_children():
		if c is TextureButton and String(c.name).begins_with("Bug_"):
			out.append(c)
	return out


func catch_bug(bug: TextureButton) -> void:
	if _finished or not is_instance_valid(bug) or bug.get_parent() != _popup:
		return
	_caught += 1
	_remove(bug)
	_refresh()


func caught() -> int:
	return _caught


func spawned() -> int:
	return _spawned


func is_finished() -> bool:
	return _finished


func finish() -> void:
	if _finished:
		return
	_finished = true
	for b: TextureButton in live_bugs():
		_remove(b)
	var before: int = _bugs_now()
	GameRunner.submit(SubmitBugHuntCommand.new(project_id, _caught))
	var removed: int = maxi(0, before - _bugs_now())
	_time.visible = false
	_caught_label.visible = false
	_result.text = tr("ui.bughunt.result").format({"n": removed})
	_result.visible = true
	_ok.visible = true


func _bugs_now() -> int:
	if GameRunner.session == null:
		return 0
	return int(StateQueries.project_status(GameRunner.session.state, project_id).get("bugs", 0))


func _spawn() -> void:
	_spawned += 1
	var card_rect: Rect2 = (_popup.get_node("%Card") as Control).get_rect()
	var free_slots: Array[Rect2] = []
	var busy: Array[Rect2] = []
	var cell := Vector2(play_rect.size.x / GRID_COLS, play_rect.size.y / GRID_ROWS)
	var live: Array[TextureButton] = live_bugs()
	for gy: int in GRID_ROWS:
		for gx: int in GRID_COLS:
			var slot := Rect2(play_rect.position + Vector2(gx * cell.x, gy * cell.y), cell)
			if slot.intersects(card_rect):
				continue
			var taken: bool = false
			for b: TextureButton in live:
				if slot.has_point(b.position + b.size / 2.0):
					taken = true
			(busy if taken else free_slots).append(slot)
	var pool: Array[Rect2] = free_slots if not free_slots.is_empty() else busy
	if pool.is_empty():
		return
	var slot: Rect2 = pool[_rng.randi() % pool.size()]
	var bug := TextureButton.new()
	bug.name = "Bug_%d" % _next_name
	_next_name += 1
	bug.texture_normal = OfficeArt.atlas(OfficeArt.EMOTES[&"bug"])
	bug.ignore_texture_size = true
	bug.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	bug.size = BUG_SIZE
	bug.position = (slot.get_center() - BUG_SIZE / 2.0).round()
	bug.set_meta(&"spawn_t", _elapsed)
	bug.pressed.connect(catch_bug.bind(bug))
	_popup.add_child(bug)


func _remove(bug: TextureButton) -> void:
	_popup.remove_child(bug)
	bug.queue_free()


func _refresh() -> void:
	if _time == null:
		return
	var left: int = ceili(maxf(0.0, tuning.bug_hunt_seconds - _elapsed))
	_time.text = tr("ui.bughunt.time").format({"seconds": left})
	_caught_label.text = tr("ui.bughunt.caught").format({"n": _caught})


func _label(node_name: String, parent: Node) -> Label:
	var l := Label.new()
	l.name = node_name
	parent.add_child(l)
	l.owner = self
	l.unique_name_in_owner = true
	return l
