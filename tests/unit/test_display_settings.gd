extends GutTest

func _s(key: String) -> Variant:
	return ProjectSettings.get_setting(key)

func test_logical_viewport_is_640x360() -> void:
	assert_eq(int(_s("display/window/size/viewport_width")), 640)
	assert_eq(int(_s("display/window/size/viewport_height")), 360)

func test_window_opens_at_1280x720() -> void:
	assert_eq(int(_s("display/window/size/window_width_override")), 1280)
	assert_eq(int(_s("display/window/size/window_height_override")), 720)

func test_integer_canvas_items_stretch() -> void:
	assert_eq(String(_s("display/window/stretch/mode")), "canvas_items")
	assert_eq(String(_s("display/window/stretch/aspect")), "keep")
	assert_eq(String(_s("display/window/stretch/scale_mode")), "integer")

func test_pixel_filter_and_snap() -> void:
	assert_eq(int(_s("rendering/textures/canvas_textures/default_texture_filter")), 0)
	assert_true(bool(_s("rendering/2d/snap/snap_2d_transforms_to_pixel")))
