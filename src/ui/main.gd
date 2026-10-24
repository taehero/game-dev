extends Control


func _enter_tree() -> void:
	GameRunner.start_new_game(int(Time.get_unix_time_from_system()), tr("ui.default_studio_name"))
