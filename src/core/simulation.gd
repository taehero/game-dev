class_name Simulation
extends RefCounted
## Weekly tick order (spec 4.2). Preloads because class_name refs are not constant expressions.

const SYSTEMS: Array[GDScript] = [
	preload("res://src/systems/calendar_system.gd"),
	preload("res://src/systems/world_event_system.gd"),
	preload("res://src/systems/market_system.gd"),
	preload("res://src/systems/staff_system.gd"),
	preload("res://src/systems/production_system.gd"),
	preload("res://src/systems/marketing_system.gd"),
	preload("res://src/systems/sales_system.gd"),
	preload("res://src/systems/live_ops_system.gd"),
	preload("res://src/systems/finance_system.gd"),
]


static func step(ctx: TickContext) -> void:
	for system: GDScript in SYSTEMS:
		system.tick(ctx)
