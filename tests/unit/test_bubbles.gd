extends GutTest

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
