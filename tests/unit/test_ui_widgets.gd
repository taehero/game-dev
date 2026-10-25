extends GutTest

const BADGE_SCENE: PackedScene = preload("res://src/ui/widgets/icon_badge.tscn")


func test_thousands() -> void:
	assert_eq(UiFormat.thousands(0), "0")
	assert_eq(UiFormat.thousands(999), "999")
	assert_eq(UiFormat.thousands(1000), "1,000")
	assert_eq(UiFormat.thousands(1234567), "1,234,567")
	assert_eq(UiFormat.thousands(-1234567), "-1,234,567")
	assert_eq(UiFormat.thousands(-999), "-999")


func test_every_icon_loads() -> void:
	for key: StringName in UiIcons.FILES:
		var tex: Texture2D = UiIcons.texture(key)
		assert_not_null(tex, "icon %s" % key)
		if tex != null:
			assert_eq(tex.get_size(), Vector2(50, 50), "size of %s" % key)


func test_unknown_icon_is_null() -> void:
	assert_null(UiIcons.texture(&"no_such_icon"))
	assert_push_warning_count(1)


func test_badge_icon_and_text_are_16px() -> void:
	var badge: IconBadge = BADGE_SCENE.instantiate()
	add_child_autofree(badge)
	badge.set_icon(&"fans", UiPalette.FANS)
	await wait_process_frames(2)
	assert_eq(badge.size, Vector2(16, 16))
	assert_true((badge.get_node("%Glyph") as TextureRect).visible)
	assert_false((badge.get_node("%Text") as Label).visible)
	var sb: StyleBoxFlat = badge.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(sb.bg_color, UiPalette.FANS)
	badge.set_text("$", UiPalette.MONEY)
	await wait_process_frames(2)
	var label: Label = badge.get_node("%Text") as Label
	assert_true(label.visible)
	assert_eq(label.text, "$")
	assert_false((badge.get_node("%Glyph") as TextureRect).visible)
	assert_eq(badge.size, Vector2(16, 16))
	sb = badge.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(sb.bg_color, UiPalette.MONEY)


func test_thousands_boundaries() -> void:
	assert_eq(UiFormat.thousands(100000), "100,000")
	assert_eq(UiFormat.thousands(1000000), "1,000,000")
	assert_eq(UiFormat.thousands(-1000), "-1,000")


func test_badge_configured_before_entering_tree() -> void:
	var badge: IconBadge = BADGE_SCENE.instantiate()
	badge.set_text("$", UiPalette.MONEY)
	add_child_autofree(badge)
	await wait_process_frames(2)
	assert_true((badge.get_node("%Text") as Label).visible)
	assert_eq((badge.get_node("%Text") as Label).text, "$")
	assert_eq((badge.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color, UiPalette.MONEY)
	assert_eq(badge.size, Vector2(16, 16))
	var b2: IconBadge = BADGE_SCENE.instantiate()
	b2.set_icon(&"fans", UiPalette.FANS)
	add_child_autofree(b2)
	await wait_process_frames(2)
	assert_true((b2.get_node("%Glyph") as TextureRect).visible)
	assert_not_null((b2.get_node("%Glyph") as TextureRect).texture)


func test_text_then_icon_restores_theme_margins() -> void:
	var badge: IconBadge = BADGE_SCENE.instantiate()
	add_child_autofree(badge)
	badge.set_icon(&"fans", UiPalette.FANS)
	await wait_process_frames(2)
	var theme_margin: float = (badge.get_theme_stylebox(&"panel") as StyleBoxFlat).content_margin_left
	badge.set_text("$", UiPalette.MONEY)
	assert_eq((badge.get_theme_stylebox(&"panel") as StyleBoxFlat).content_margin_left, 0.0)
	badge.set_icon(&"fans", UiPalette.FANS)
	await wait_process_frames(2)
	assert_eq((badge.get_theme_stylebox(&"panel") as StyleBoxFlat).content_margin_left, theme_margin)
	assert_eq(badge.size, Vector2(16, 16))
