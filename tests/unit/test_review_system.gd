extends GutTest

var s: GameState
var t: TuningDef
var db: ContentDB


func before_each() -> void:
	s = Fixtures.new_state(1)
	t = Fixtures.tuning()
	db = Fixtures.content()


func test_match_bp_per_stage() -> void:
	var ideal: Array[int] = [5000, 3000, 2000, 3000, 3000, 4000, 4000, 3000, 3000]
	assert_eq(ReviewSystem.match_bp(ideal, ideal, 0), 10000)
	var f: Array[int] = [3000, 3000, 4000, 3000, 3000, 4000, 4000, 3000, 3000]
	assert_eq(ReviewSystem.match_bp(f, ideal, 0), 6000)
	var a: Array[int] = [10000, 0, 0, 0, 0, 0, 0, 0, 0]
	var b: Array[int] = [0, 0, 10000, 0, 0, 0, 0, 0, 0]
	assert_eq(ReviewSystem.match_bp(a, b, 0), 0)


func test_fit_to_x10() -> void:
	assert_eq(ReviewSystem.fit_to_x10(5000), 10)
	assert_eq(ReviewSystem.fit_to_x10(10000), 55)
	assert_eq(ReviewSystem.fit_to_x10(15000), 100)


func test_reasons_match_strong_art_and_weak_tech() -> void:
	var pid := Fixtures.add_project(s, {"phase": Project.Phase.POLISH, "bugs": 30,
		"points": {&"art": 20000, &"audio": 1000, &"design": 3000, &"tech": 100}})
	var dims := ReviewSystem.dimension_scores(s, db, t, pid)
	assert_eq(dims[&"graphics"], 100)
	assert_eq(dims[&"bugs"], 98)
	assert_eq(dims[&"tech"], 10)
	var r := ReviewSystem.outlet_review(dims, db.outlets[&"outlet_fx_b"], db, s.rng, t)
	assert_eq(r.strength_key, &"review.strong.graphics")
	assert_eq(r.weakness_key, &"review.weak.tech")


func test_tech_capped_by_engine() -> void:
	var pid := Fixtures.add_project(s, {"points": {&"tech": 999999}})
	assert_eq(ReviewSystem.dimension_scores(s, db, t, pid)[&"tech"], 40)


func test_empty_project_scores_clamp_and_still_has_reasons() -> void:
	var pid := Fixtures.add_project(s, {"phase": Project.Phase.POLISH, "bugs": 50})
	var dims := ReviewSystem.dimension_scores(s, db, t, pid)
	for d: StringName in ReviewOutletDef.DIMENSIONS:
		assert_between(dims[d], 10, 100, String(d))
	var r := ReviewSystem.outlet_review(dims, db.outlets[&"outlet_fx_a"], db, s.rng, t)
	assert_ne(r.strength_key, &"")
	assert_ne(r.weakness_key, &"")


func test_noise_within_three_and_one_draw_per_outlet() -> void:
	var pid := Fixtures.add_project(s, {"points": {&"art": 3000, &"audio": 1000, &"design": 3000, &"tech": 3000}})
	var dims := ReviewSystem.dimension_scores(s, db, t, pid)
	var o: ReviewOutletDef = db.outlets[&"outlet_fx_a"]
	var mean: int = 0
	for d: StringName in ReviewOutletDef.DIMENSIONS:
		mean += dims[d]
	mean /= 10
	var before: int = s.rng.state
	var r := ReviewSystem.outlet_review(dims, o, db, s.rng, t)
	assert_between(r.score_x10, mean - 3, mean + 3)
	var probe := RandomNumberGenerator.new()
	probe.state = before
	probe.randi_range(-3, 3)
	assert_eq(s.rng.state, probe.state)


func test_new_combo_raises_innovation() -> void:
	var pid := Fixtures.add_project(s, {})
	var fresh: int = ReviewSystem.dimension_scores(s, db, t, pid)[&"innovation"]
	Fixtures.add_project(s, {"phase": Project.Phase.LIVE})
	var repeat: int = ReviewSystem.dimension_scores(s, db, t, pid)[&"innovation"]
	assert_eq(fresh - repeat, t.review_innovation_new_combo_x10)


func test_pick_template_threshold_and_fallback() -> void:
	assert_eq(ReviewSystem.pick_template(db, &"art", true, 100), &"review.strong.generic", "unknown dimension falls back")
	assert_eq(ReviewSystem.pick_template(db, &"graphics", true, 69), &"review.strong.generic")
	assert_eq(ReviewSystem.pick_template(db, &"graphics", true, 70), &"review.strong.graphics")
	assert_eq(ReviewSystem.pick_template(db, &"graphics", false, 41), &"review.weak.generic")
	assert_eq(ReviewSystem.pick_template(db, &"graphics", false, 40), &"review.weak.graphics")
