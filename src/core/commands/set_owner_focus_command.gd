class_name SetOwnerFocusCommand
extends Command

var focus_dev_bp: int


func _init(p_focus_dev_bp: int) -> void:
	focus_dev_bp = p_focus_dev_bp


func validate(_state: GameState, _tuning: TuningDef) -> CommandResult:
	if focus_dev_bp < 0 or focus_dev_bp > Fixed.ONE_BP:
		return CommandResult.fail(&"error.invalid_focus")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	ctx.state.owner.focus_dev_bp = focus_dev_bp
