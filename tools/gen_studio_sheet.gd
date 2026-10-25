extends SceneTree
## Run: godot --headless -s tools/gen_studio_sheet.gd


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(StudioSheet.OUT_PATH).get_base_dir())
	StudioSheet.build().save_png(ProjectSettings.globalize_path(StudioSheet.OUT_PATH))
	quit()
