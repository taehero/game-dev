extends Control

const OFFICE_SCALE: int = 2
const OFFICE_AREA := Rect2i(0, 0, 640, 316)


static func office_origin(room_px: Vector2i) -> Vector2i:
	return OFFICE_AREA.position + (OFFICE_AREA.size - room_px * OFFICE_SCALE) / 2


func _enter_tree() -> void:
	GameRunner.start_new_game(int(Time.get_unix_time_from_system()), tr("ui.default_studio_name"))


func _ready() -> void:
	(get_node("TabBarShell") as TabBarShell).tab_changed.connect(_on_tab_changed)


func toggle_debug_hud() -> void:
	var hud: Control = get_node("DebugLayer/DebugHud") as Control
	hud.visible = not hud.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_toggle_hud"):
		toggle_debug_hud()


func _on_tab_changed(tab: StringName) -> void:
	var host: PanelHost = get_node("PanelHost") as PanelHost
	if tab == &"":
		host.hide_panel()
	else:
		host.show_tab(tab)
