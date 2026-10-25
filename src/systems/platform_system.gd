class_name PlatformSystem
extends RefCounted


## The install curve has one point per quarter (weeks_per_year / 4 weeks).
@warning_ignore("integer_division")
static func install_base(def: PlatformDef, week: int, t: TuningDef) -> int:
	if week < def.launch_week or def.install_curve.is_empty():
		return 0
	var step: int = t.weeks_per_year / 4
	var elapsed: int = week - def.launch_week
	var q: int = elapsed / step
	var r: int = elapsed % step
	var last: int = def.install_curve.size() - 1
	if q >= last:
		return def.install_curve[last]
	var a: int = def.install_curve[q]
	var b: int = def.install_curve[q + 1]
	return a + (b - a) * r / step


static func tick(ctx: TickContext) -> void:
	var week: int = ctx.state.week
	for id: StringName in GameState.sorted_names(ctx.content.platforms):
		var def: PlatformDef = ctx.content.platforms[id]
		if week >= def.launch_week:
			ctx.state.market.platform_install_base[id] = install_base(def, week, ctx.tuning)
		if def.rumor_weeks > 0 and week == def.launch_week - def.rumor_weeks:
			ctx.emit(&"platform_rumored", {"platform_id": id})
		if week == def.launch_week:
			ctx.emit(&"platform_launched", {"platform_id": id})
		if week == def.end_week:
			ctx.emit(&"platform_retired", {"platform_id": id})
