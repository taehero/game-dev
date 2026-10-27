class_name ScenarioM2C
extends RefCounted
## Test helper: the M2c marketing, live-ops, promotion, forum and award specs. Reached from Scenario._make_command.

const SCRIPT_M2C: Dictionary = {
	0: [["hire", "Ada", 800], ["place_equipment", "equipment_micro_1980", 1],
		["start_game", "Star Run", "size_small", "platform_nova8", "topic_space", "genre_action", "lic_engine_homebrew", []],
		["sliders_ideal"]],
	15: [["run_marketing", "channel_magazine_ad"]],
	20: [["release"]],
	22: [["buy_research", "research_scrolling"], ["start_engine", "Scroll Engine", ["feature_scrolling"]]],
	28: [["buy_dev_kit", "platform_arcadia"],
		["start_game", "Kick Arena", "size_small", "platform_arcadia", "topic_sports", "genre_action", "last_engine", ["feature_scrolling"]],
		["sliders_ideal"]],
	48: [["release"]],
	49: [["enter_award", "award_golden_cartridge"], ["start_patch"]],
	54: [["start_dlc", "Kick Arena: Extra Time"]],
	62: [["release"]],
	64: [["build_mod_tools"]],
	68: [["start_promotion", 2000, 2]],
	72: [["start_promotion", 3000, 1]],
}


static func make(state: GameState, spec: Array) -> Command:
	match spec[0]:
		"run_marketing":
			var dev: int = -1
			for id: int in state.sorted_ids(state.projects):
				var p: Project = state.projects[id]
				if p.kind == Project.Kind.GAME and (p.phase == Project.Phase.PRODUCTION or p.phase == Project.Phase.POLISH):
					dev = id
			return RunMarketingCommand.new(dev, StringName(spec[1]))
		"enter_award":
			return EnterAwardCommand.new(_live_game(state), StringName(spec[1]))
		"start_patch":
			return StartPatchCommand.new(_live_game(state))
		"build_mod_tools":
			return BuildModToolsCommand.new(_live_game(state))
		"start_dlc":
			return StartDLCCommand.new(_live_game(state), spec[1])
		"start_promotion":
			return StartPromotionCommand.new(_live_game(state), spec[1], spec[2])
		"reply_forum":
			for f: ForumPost in state.forum_posts:
				if not f.replied:
					return ReplyForumCommand.new(f.id, StringName(spec[1]))
	return null


## The latest LIVE GAME that is not a DLC.
static func _live_game(state: GameState) -> int:
	var found: int = -1
	for id: int in state.sorted_ids(state.projects):
		var p: Project = state.projects[id]
		if p.kind == Project.Kind.GAME and p.phase == Project.Phase.LIVE and p.parent_id == -1:
			found = id
	return found
