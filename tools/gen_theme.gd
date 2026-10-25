extends SceneTree
## Regenerates main_theme.tres: godot --headless -s tools/gen_theme.gd


func _init() -> void:
    var err := ResourceSaver.save(ThemeBuilder.build(), "res://src/ui/theme/main_theme.tres")
    if err != OK:
        push_error("gen_theme: save failed (%d)" % err)
    quit()
