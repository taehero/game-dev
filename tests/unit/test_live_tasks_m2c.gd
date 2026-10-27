extends GutTest


func _setup() -> Array:
	var s := Fixtures.new_state(1)
	for sid: int in s.staff:
		s.staff[sid].seat_index = -1
	var w1: int = Fixtures.add_worker(s)
	var w2: int = Fixtures.add_worker(s)
	var pid: int = Fixtures.add_project(s, {"phase": Project.Phase.LIVE, "bugs": 20, "user_score": 60})
	return [s, pid, w1, w2]


func _ctx(s: GameState) -> TickContext:
	return TickContext.new(s, Fixtures.tuning())


func _patch(s: GameState, pid: int) -> void:
	StartPatchCommand.new(pid).apply(_ctx(s))


func test_start_patch_assigns_free_workers() -> void:
	var r := _setup()
	var s: GameState = r[0]
	assert_true(StartPatchCommand.new(r[1]).validate(s, Fixtures.tuning()).ok)
	_patch(s, r[1])
	assert_eq(s.staff[r[2]].assigned_project_id, r[1])
	assert_eq(s.staff[r[3]].assigned_project_id, r[1])
	var p: Project = s.projects[r[1]]
	assert_eq(p.live_task, Project.LiveTask.PATCH)
	assert_eq(p.live_task_left, 4)


func test_patch_runs_and_completes() -> void:
	var r := _setup()
	var s: GameState = r[0]
	_patch(s, r[1])
	var p: Project = s.projects[r[1]]
	LiveOpsSystem.tick(_ctx(s))
	assert_eq(p.bugs, 10)
	assert_eq(p.live_task_left, 2)
	LiveOpsSystem.tick(_ctx(s))
	assert_eq(p.bugs, 0)
	assert_eq(p.live_task_left, 0)
	assert_eq(p.user_score, 63)
	assert_eq(p.sentiment, 5)
	assert_eq(p.live_task, Project.LiveTask.NONE)
	assert_eq(s.staff[r[2]].assigned_project_id, -1)
	assert_eq(s.staff[r[3]].assigned_project_id, -1)


func test_patch_stalls_without_workers() -> void:
	var r := _setup()
	var s: GameState = r[0]
	_patch(s, r[1])
	s.staff[r[2]].seat_index = -1
	s.staff[r[3]].seat_index = -1
	LiveOpsSystem.tick(_ctx(s))
	assert_eq(s.projects[r[1]].live_task_left, 4)


func test_task_cancelled_when_project_retires() -> void:
	var r := _setup()
	var s: GameState = r[0]
	_patch(s, r[1])
	var p: Project = s.projects[r[1]]
	p.phase = Project.Phase.RETIRED
	LiveOpsSystem.tick(_ctx(s))
	assert_eq(p.live_task, Project.LiveTask.NONE)
	assert_eq(p.live_task_left, 0)
	assert_eq(p.bugs, 20)
	assert_eq(s.staff[r[2]].assigned_project_id, -1)
	assert_eq(s.staff[r[3]].assigned_project_id, -1)


func test_build_mod_tools_completes() -> void:
	var r := _setup()
	var s: GameState = r[0]
	BuildModToolsCommand.new(r[1]).apply(_ctx(s))
	assert_eq(s.projects[r[1]].live_task_left, 8)
	for _i: int in 4:
		LiveOpsSystem.tick(_ctx(s))
	assert_true(s.projects[r[1]].mod_tools)
	assert_eq(s.projects[r[1]].live_task, Project.LiveTask.NONE)
	assert_eq(s.staff[r[2]].assigned_project_id, -1)


func test_rejects_not_live() -> void:
	var r := _setup()
	var s: GameState = r[0]
	s.projects[r[1]].phase = Project.Phase.RETIRED
	assert_eq(StartPatchCommand.new(r[1]).validate(s, Fixtures.tuning()).reason_key, &"error.project_not_live")
	assert_eq(StartPatchCommand.new(999).validate(s, Fixtures.tuning()).reason_key, &"error.project_not_found")


func test_rejects_task_running() -> void:
	var r := _setup()
	var s: GameState = r[0]
	_patch(s, r[1])
	assert_eq(BuildModToolsCommand.new(r[1]).validate(s, Fixtures.tuning()).reason_key, &"error.live_task_running")


func test_rejects_no_free_workers() -> void:
	var r := _setup()
	var s: GameState = r[0]
	s.staff[r[2]].seat_index = -1
	s.staff[r[3]].seat_index = -1
	assert_eq(StartPatchCommand.new(r[1]).validate(s, Fixtures.tuning()).reason_key, &"error.not_enough_staff")


func test_rejects_no_bugs() -> void:
	var r := _setup()
	var s: GameState = r[0]
	s.projects[r[1]].bugs = 0
	assert_eq(StartPatchCommand.new(r[1]).validate(s, Fixtures.tuning()).reason_key, &"error.no_bugs")


func test_rejects_mod_tools_built() -> void:
	var r := _setup()
	var s: GameState = r[0]
	s.projects[r[1]].mod_tools = true
	assert_eq(BuildModToolsCommand.new(r[1]).validate(s, Fixtures.tuning()).reason_key, &"error.mod_tools_built")


func test_sentiment_clamped() -> void:
	var p := Project.new()
	LiveOpsSystem.change_sentiment(p, 500)
	assert_eq(p.sentiment, 100)
	LiveOpsSystem.change_sentiment(p, -500)
	assert_eq(p.sentiment, -100)


func test_task_cancelled_when_all_workers_removed() -> void:
	var r := _setup()
	var s: GameState = r[0]
	_patch(s, r[1])
	var ctx := _ctx(s)
	FireStaffCommand.new(r[2]).apply(ctx)
	FireStaffCommand.new(r[3]).apply(ctx)
	LiveOpsSystem.tick(ctx)
	var p: Project = s.projects[r[1]]
	assert_eq(p.live_task, Project.LiveTask.NONE)
	assert_eq(p.live_task_left, 0)
	assert_eq(p.bugs, 20)
	Fixtures.add_worker(s)
	assert_true(StartPatchCommand.new(r[1]).validate(s, Fixtures.tuning()).ok)


func test_promise_patch_refused_after_cancel() -> void:
	var r := _setup()
	var s: GameState = r[0]
	_patch(s, r[1])
	var f := ForumPost.new()
	f.id = s.alloc_id()
	f.project_id = r[1]
	s.forum_posts.append(f)
	var ctx := _ctx(s)
	FireStaffCommand.new(r[2]).apply(ctx)
	FireStaffCommand.new(r[3]).apply(ctx)
	LiveOpsSystem.tick(ctx)
	assert_false(ReplyForumCommand.new(f.id, &"promise_patch").validate(s, Fixtures.tuning()).ok)
