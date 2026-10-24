extends Control


func _ready() -> void:
	GameRunner.start_new_game(int(Time.get_unix_time_from_system()), tr("ui.default_studio_name"))
