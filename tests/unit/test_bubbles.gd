extends GutTest

func after_each() -> void:
	TranslationServer.set_locale("en")


func _layer() -> BubbleLayer:
	return add_child_autofree(BubbleLayer.new())

func test_spawn_adds_coloured_bubble() -> void:
	var l := _layer()
	var b := l.spawn(Vector2(10, 10), &"tech")
	assert_not_null(b)
	assert_eq(b.kind, &"tech")
	assert_eq(l.live_count(), 1)

func test_unknown_kind_spawns_nothing() -> void:
	var l := _layer()
	assert_null(l.spawn(Vector2.ZERO, &"juggling"))
	assert_eq(l.live_count(), 0)

func test_bubble_count_is_capped() -> void:
	var l := _layer()
	for i: int in 30:
		l.spawn(Vector2.ZERO, &"design")
	await wait_process_frames(1)
	assert_eq(l.live_count(), BubbleLayer.MAX_BUBBLES)

func test_bubble_rises_and_frees_itself() -> void:
	var l := _layer()
	l.spawn(Vector2(0, 50), &"bug")
	await wait_seconds(Bubble.LIFETIME_S + 0.2)
	assert_eq(l.live_count(), 0)

func test_successive_spawns_shift_x_deterministically() -> void:
	var l := _layer()
	var xs: Array[float] = []
	for i: int in 4:
		xs.append(l.spawn(Vector2(10, 0), &"art").position.x)
	assert_eq(xs, [7.0, 10.0, 13.0, 7.0] as Array[float])


func test_bubble_rises_and_fades_midway() -> void:
	var l := _layer()
	var b := l.spawn(Vector2(0, 50), &"bug")
	await wait_seconds(Bubble.LIFETIME_S - 0.1)
	assert_lt(b.position.y, 50.0, "rose")
	assert_lt(b.modulate.a, 1.0, "fading")


func test_oldest_bubble_is_freed_first_at_cap() -> void:
	var l := _layer()
	var first := l.spawn(Vector2.ZERO, &"art")
	var second := l.spawn(Vector2.ZERO, &"art")
	for i: int in BubbleLayer.MAX_BUBBLES - 2:
		l.spawn(Vector2.ZERO, &"art")
	assert_false(first.is_queued_for_deletion())
	l.spawn(Vector2.ZERO, &"art")
	assert_true(first.is_queued_for_deletion(), "oldest freed")
	assert_false(second.is_queued_for_deletion())


func test_points_bubble_shows_amount_pill() -> void:
	var b := _layer().spawn(Vector2.ZERO, &"design", 3)
	var pill: PanelContainer = b.get_node("Pill")
	assert_eq(b.pill_text(), tr("ui.bubble.points").format({"amount": 3, "type": tr("ui.point.design")}))
	assert_true(pill.visible)
	var box: StyleBoxFlat = pill.get_theme_stylebox(&"panel") as StyleBoxFlat
	assert_eq(box.bg_color, UiPalette.POINT_COLORS[&"design"])


func test_bug_bubble_says_bug() -> void:
	var b := _layer().spawn(Vector2.ZERO, &"bug")
	assert_eq(b.pill_text(), tr("ui.bubble.bug"))
	assert_true((b.get_node("Pill") as PanelContainer).visible)


func test_zero_amount_hides_pill() -> void:
	var b := _layer().spawn(Vector2.ZERO, &"art")
	assert_false((b.get_node("Pill") as PanelContainer).visible)


func test_icon_uses_emote_cell() -> void:
	var l := _layer()
	for kind: StringName in OfficeArt.EMOTES:
		var b := l.spawn(Vector2.ZERO, kind)
		var tex := (b.get_node("Icon") as Sprite2D).texture as AtlasTexture
		assert_eq(tex.region, Rect2(OfficeArt.region(OfficeArt.EMOTES[kind])), str(kind))


func test_pill_renders_at_logical_scale() -> void:
	var root: Node2D = add_child_autofree(Node2D.new())
	root.scale = Vector2(2, 2)
	var l := BubbleLayer.new()
	root.add_child(l)
	var b := l.spawn(Vector2.ZERO, &"tech", 1)
	await wait_process_frames(1)
	assert_true((b.get_node("Pill") as Control).get_global_transform().get_scale().is_equal_approx(Vector2.ONE))


func test_cap_counts_bubbles_not_pills() -> void:
	var l := _layer()
	for i: int in 30:
		l.spawn(Vector2.ZERO, &"tech", 5)
	await wait_process_frames(1)
	assert_eq(l.live_count(), BubbleLayer.MAX_BUBBLES)
	for child: Node in l.get_children():
		assert_true(child is Bubble)
