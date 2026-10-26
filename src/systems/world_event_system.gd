class_name WorldEventSystem
extends RefCounted


## Spec 4.2 step 2. Production events live here (Ruling P3); M3 adds world events next to this call.
static func tick(ctx: TickContext) -> void:
	ProductionEventSystem.tick(ctx)
