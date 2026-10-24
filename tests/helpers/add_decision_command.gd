class_name AddDecisionCommand
extends Command
## Test-only command: appends a pending Decision.


func apply(ctx: TickContext) -> void:
	var d := Decision.new()
	d.id = ctx.state.alloc_id()
	d.kind = &"test_decision"
	d.deadline_week = ctx.state.week + 4
	ctx.state.pending_decisions.append(d)
