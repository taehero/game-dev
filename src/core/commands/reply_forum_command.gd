class_name ReplyForumCommand
extends Command

const REPLIES: Array[StringName] = [&"apologise", &"promise_patch", &"ignore"]

var post_id: int
var reply: StringName


func _init(p_post_id: int, p_reply: StringName) -> void:
	post_id = p_post_id
	reply = p_reply


func _post(state: GameState) -> ForumPost:
	for f: ForumPost in state.forum_posts:
		if f.id == post_id:
			return f
	return null


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	if not REPLIES.has(reply):
		return CommandResult.fail(&"error.invalid_reply")
	var f: ForumPost = _post(state)
	if f == null:
		return CommandResult.fail(&"error.post_not_found")
	if f.replied:
		return CommandResult.fail(&"error.post_replied")
	if reply == &"promise_patch":
		if not state.projects.has(f.project_id) or state.projects[f.project_id].live_task != Project.LiveTask.PATCH:
			return CommandResult.fail(&"error.no_patch_running")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var f: ForumPost = _post(ctx.state)
	f.replied = true
	var delta: int = 0
	if reply == &"apologise":
		delta = ctx.tuning.forum_apologise_sentiment
	elif reply == &"promise_patch":
		delta = ctx.tuning.forum_promise_sentiment
	if ctx.state.projects.has(f.project_id):
		LiveOpsSystem.change_sentiment(ctx.state.projects[f.project_id], delta)
	ctx.emit(&"project_changed", {"project_id": f.project_id})
