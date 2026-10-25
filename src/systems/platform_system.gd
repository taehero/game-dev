class_name PlatformSystem
extends RefCounted

## Weeks per install-curve segment (one quarter).
const CURVE_STEP_WEEKS: int = 13


static func install_base(def: PlatformDef, week: int) -> int:
	if week < def.launch_week or def.install_curve.is_empty():
		return 0
	var elapsed: int = week - def.launch_week
	var q: int = elapsed / CURVE_STEP_WEEKS
	var r: int = elapsed % CURVE_STEP_WEEKS
	var last: int = def.install_curve.size() - 1
	if q >= last:
		return def.install_curve[last]
	var a: int = def.install_curve[q]
	var b: int = def.install_curve[q + 1]
	return a + (b - a) * r / CURVE_STEP_WEEKS


static func tick(ctx: TickContext) -> void:
	var week: int = ctx.state.week
	for id: StringName in GameState.sorted_names(ctx.content.platforms):
		var def: PlatformDef = ctx.content.platforms[id]
		if week >= def.launch_week:
			ctx.state.market.platform_install_base[id] = install_base(def, week)
		if def.rumor_weeks > 0 and week == def.launch_week - def.rumor_weeks:
			ctx.emit(&"platform_rumored", {"platform_id": id})
		if week == def.launch_week:
			ctx.emit(&"platform_launched", {"platform_id": id})
		if week == def.end_week:
			ctx.emit(&"platform_retired", {"platform_id": id})
