class_name CalendarSystem
extends RefCounted


static func tick(ctx: TickContext) -> void:
	ctx.state.week += 1
	ctx.emit(&"week_ticked", {"week": ctx.state.week})
