extends Control

const OFFICE_SCALE: int = 2
const OFFICE_SCENE: PackedScene = preload("res://src/ui/office/office_scene.tscn")
const OFFICE_AREA := Rect2i(64, 30, 576, 296)


static func office_origin(room_px: Vector2i) -> Vector2i:
	return OFFICE_AREA.position + (OFFICE_AREA.size - room_px * OFFICE_SCALE) / 2


func _enter_tree() -> void:
	GameRunner.start_new_game(int(Time.get_unix_time_from_system()), tr("ui.default_studio_name"))


var _office: OfficeScene
var _queue: PopupQueue
var _director: PopupDirector


func _ready() -> void:
	(get_node("Dock") as Dock).tab_changed.connect(_on_tab_changed)
	(get_node("PanelHost") as PanelHost).close_requested.connect((get_node("Dock") as Dock).close_all)
	(get_node("ProjectCard") as ProjectCard).configure(_content_names())
	_office = OFFICE_SCENE.instantiate() as OfficeScene
	_office.scale = Vector2(OFFICE_SCALE, OFFICE_SCALE)
	get_node("OfficeSlot").add_child(_office)
	var content: Array = _office_content()
	var offices: Dictionary[StringName, OfficeDef] = content[0]
	var equipment: Dictionary[StringName, EquipmentDef] = content[1]
	_office.configure(offices, equipment)
	_office.room_changed.connect(_centre_office)
	if GameRunner.session != null:
		_office.refresh(GameRunner.session.state, GameRunner.session.tuning)
	_centre_office()
	_build_popups_and_panels()


func _build_popups_and_panels() -> void:
	_queue = PopupQueue.new(get_node("Popups") as Control, GameRunner.pause_for_popup, GameRunner.resume_after_popup)
	var db: ContentDB = ContentDB.active()
	_director = PopupDirector.new()
	_director.name = "PopupDirector"
	add_child(_director)
	_director.setup(_queue, db, Rect2(OFFICE_AREA))
	var host: PanelHost = get_node("PanelHost") as PanelHost
	var project := ProjectPanel.new()
	project.configure(db)
	project.new_game_requested.connect(_director.show_new_game)
	project.new_engine_requested.connect(_director.show_new_engine)
	project.bug_hunt_requested.connect(_director.show_bug_hunt_offer)
	project.details_requested.connect(_director.show_sales)
	host.set_panel(&"project", project)
	var panels: Dictionary[StringName, PanelBase] = {
		&"team": TeamPanel.new(), &"equipment": EquipmentPanel.new(),
		&"finance": FinancePanel.new(), &"market": MarketPanel.new()}
	for tab: StringName in panels:
		panels[tab].configure(db)
		host.set_panel(tab, panels[tab])


## Ruling 5: Main is the only place the UI reads ContentDB.active(), here and in _content_names().
func _office_content() -> Array:
	var db: ContentDB = ContentDB.active()
	return [db.offices, db.equipment]


## Ruling 13: id -> name_key for every topic and genre, for the project card.
func _content_names() -> Dictionary[StringName, StringName]:
	var db: ContentDB = ContentDB.active()
	var out: Dictionary[StringName, StringName] = {}
	for id: StringName in db.topics:
		out[id] = db.topics[id].name_key
	for id: StringName in db.genres:
		out[id] = db.genres[id].name_key
	return out


func show_popup(popup: PopupCard) -> void:
	_queue.push(popup)


func _centre_office() -> void:
	var room: OfficeRoom = _office.room()
	if room == null:
		return
	_office.position = Vector2(office_origin(room.pixel_size()))


func toggle_debug_hud() -> void:
	var hud: Control = get_node("DebugLayer/DebugHud") as Control
	hud.visible = not hud.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle_hud"):
		toggle_debug_hud()


func _on_tab_changed(tab: StringName) -> void:
	var host: PanelHost = get_node("PanelHost") as PanelHost
	(get_node("ProjectCard") as Control).visible = tab == &""
	if tab == &"":
		host.hide_panel()
	else:
		host.show_tab(tab)
