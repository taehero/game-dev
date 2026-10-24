class_name Command
extends RefCounted
## Base class for player commands. Only commands and systems change GameState.


func validate(_state: GameState, _tuning: TuningDef) -> CommandResult:
	return CommandResult.success()


func apply(_ctx: TickContext) -> void:
	pass
