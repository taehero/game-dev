class_name ReviewSystem
extends RefCounted
## Review scores for a released game (spec 6.5). Called by ReleaseProjectCommand, not part of SYSTEMS.


## Spec 6.5: how close the stage's three sliders are to the genre ideal, in bp.
static func match_bp(focus: Array[int], ideal: Array[int], stage: int) -> int:
	var diff: int = 0
	for j: int in 3:
		diff += absi(focus[3 * stage + j] - ideal[3 * stage + j])
	return maxi(0, Fixed.ONE_BP - diff)


@warning_ignore("integer_division")
static func fit_to_x10(fit_bp: int) -> int:
	return clampi(10 + (fit_bp - 5000) * 90 / 10000, 10, 100)


@warning_ignore("integer_division")
static func quality_x10(points: int, par: int, t: TuningDef) -> int:
	return clampi(Fixed.mul_bp(t.review_par_score_x10, points * Fixed.ONE_BP / maxi(1, par)), 10, 100)


@warning_ignore("integer_division")
static func par_for(type: StringName, size: ProjectSizeDef, genre: GenreDef) -> int:
	var sum: int = 0
	for i: int in GameRules.SLIDER_TYPES.size():
		if GameRules.SLIDER_TYPES[i] == type and i < genre.ideal_sliders.size():
			sum += genre.ideal_sliders[i]
	return Fixed.mul_bp(size.par_points, sum / 3)


@warning_ignore("integer_division")
static func dimension_scores(state: GameState, content: ContentDB, t: TuningDef, project_id: int) -> Dictionary[StringName, int]:
	var p: Project = state.projects[project_id]
	var genre_id: StringName = p.config.get(&"genre", &"")
	var topic_id: StringName = p.config.get(&"topic", &"")
	var size: ProjectSizeDef = content.sizes.get(p.size_id, null)
	var genre: GenreDef = content.genres.get(genre_id, null)
	if size == null:
		size = ProjectSizeDef.new()
	if genre == null:
		genre = GenreDef.new()
	var q: Dictionary[StringName, int] = {}
	var total_points: int = 0
	for type: StringName in GameRules.SKILL_ORDER:
		var pts: int = p.points.get(type, 0)
		total_points += pts
		q[type] = quality_x10(pts, par_for(type, size, genre), t)
	var m_sum: int = 0
	var m0: int = 10
	for s: int in 3:
		var m: int = 10
		if genre.ideal_sliders.size() >= 9 and p.focus.size() >= 9:
			m = 10 + Fixed.mul_bp(90, match_bp(p.focus, genre.ideal_sliders, s))
		if s == 0:
			m0 = m
		m_sum += m
	var d: Dictionary[StringName, int] = {}
	d[&"gameplay"] = (q[&"design"] + m_sum / 3) / 2
	d[&"tech"] = mini(q[&"tech"], maxi(10, GameRules.engine_tech_cap(state, content, p)))
	d[&"graphics"] = q[&"art"]
	d[&"audio"] = q[&"audio"]
	d[&"story"] = (q[&"design"] + m0) / 2
	var new_combo: bool = true
	for oid: int in state.sorted_ids(state.projects):
		var o: Project = state.projects[oid]
		if oid != project_id and o.company_id == p.company_id and o.kind == Project.Kind.GAME \
				and o.phase >= Project.Phase.RELEASED \
				and o.config.get(&"topic", &"") == topic_id and o.config.get(&"genre", &"") == genre_id:
			new_combo = false
			break
	d[&"innovation"] = clampi(t.review_innovation_base_x10 + p.features.size() * t.review_innovation_per_feature_x10 \
			+ (t.review_innovation_new_combo_x10 if new_combo else 0), 10, 100)
	var density: int = p.bugs * Fixed.ONE_BP / maxi(1, total_points)
	d[&"bugs"] = clampi(100 - density / maxi(1, t.review_bug_density_divisor), 10, 100)
	var platform: PlatformDef = content.platforms.get(p.config.get(&"platform", &""), null)
	var platform_fit: int = Fixed.ONE_BP if platform == null else platform.genre_fit_bp.get(genre_id, Fixed.ONE_BP)
	d[&"platform_fit"] = fit_to_x10(platform_fit)
	var topic: TopicDef = content.topics.get(topic_id, null)
	var market_fit: int = Fixed.ONE_BP if topic == null else topic.genre_fit_bp.get(genre_id, Fixed.ONE_BP)
	d[&"market_fit"] = fit_to_x10(market_fit)
	d[&"value"] = (d[&"gameplay"] + d[&"bugs"]) / 2
	var out: Dictionary[StringName, int] = {}
	for dim: StringName in ReviewOutletDef.DIMENSIONS:
		out[dim] = d[dim]
	return out


## Strength: highest qualifying threshold. Weakness: lowest. Ties go to the smaller template id.
static func pick_template(content: ContentDB, dimension: StringName, is_strength: bool, score_x10: int) -> StringName:
	var best: ReviewTemplateDef = null
	var generic: ReviewTemplateDef = null
	for id: StringName in GameState.sorted_names(content.review_templates):
		var tpl: ReviewTemplateDef = content.review_templates[id]
		if tpl.is_strength != is_strength:
			continue
		if tpl.dimension == &"generic" and generic == null:
			generic = tpl
		if tpl.dimension != dimension:
			continue
		if is_strength:
			if score_x10 < tpl.threshold_x10:
				continue
			if best == null or tpl.threshold_x10 > best.threshold_x10:
				best = tpl
		else:
			if score_x10 > tpl.threshold_x10:
				continue
			if best == null or tpl.threshold_x10 < best.threshold_x10:
				best = tpl
	if best != null:
		return best.text_key
	if generic != null:
		return generic.text_key
	return &"review.strong.generic" if is_strength else &"review.weak.generic"


@warning_ignore("integer_division")
static func outlet_review(dims: Dictionary[StringName, int], outlet: ReviewOutletDef, content: ContentDB, rng: RandomNumberGenerator, t: TuningDef) -> ReviewResult:
	var weighted: int = 0
	var weight_sum: int = 0
	var strong_dim: StringName = &""
	var weak_dim: StringName = &""
	for dim: StringName in ReviewOutletDef.DIMENSIONS:
		var w: int = outlet.weights_bp.get(dim, 0)
		if w <= 0:
			continue
		var v: int = dims[dim]
		weighted += w * v
		weight_sum += w
		if strong_dim == &"" or v > dims[strong_dim]:
			strong_dim = dim
		if weak_dim == &"" or v < dims[weak_dim]:
			weak_dim = dim
	var base: int = weighted / maxi(1, weight_sum)
	var r := ReviewResult.new()
	r.outlet_id = outlet.id
	r.score_x10 = clampi(base + outlet.bias_x10 + rng.randi_range(-t.review_noise_x10, t.review_noise_x10), 10, 100)
	r.strength_key = pick_template(content, strong_dim, true, dims.get(strong_dim, 0))
	r.weakness_key = pick_template(content, weak_dim, false, dims.get(weak_dim, 0))
	return r


@warning_ignore("integer_division")
static func review_project(ctx: TickContext, project_id: int) -> void:
	var p: Project = ctx.state.projects[project_id]
	var dims: Dictionary[StringName, int] = dimension_scores(ctx.state, ctx.content, ctx.tuning, project_id)
	p.review_results.clear()
	var sum: int = 0
	for oid: StringName in GameState.sorted_names(ctx.content.outlets):
		var r: ReviewResult = outlet_review(dims, ctx.content.outlets[oid], ctx.content, ctx.rng, ctx.tuning)
		p.review_results.append(r)
		sum += r.score_x10
	p.user_score = sum / maxi(1, p.review_results.size())
	ctx.emit(&"review_published", {"project_id": project_id})
