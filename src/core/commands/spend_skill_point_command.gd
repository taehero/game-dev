class_name SpendSkillPointCommand
extends Command

var perk_id: StringName


func _init(p_perk_id: StringName) -> void:
	perk_id = p_perk_id


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	var content: ContentDB = ContentDB.active()
	if not content.perks.has(perk_id):
		return CommandResult.fail(&"error.perk_not_found")
	if state.owner.skill_points < 1:
		return CommandResult.fail(&"error.no_skill_points")
	if state.owner.perks.get(perk_id, 0) >= content.perks[perk_id].max_rank:
		return CommandResult.fail(&"error.perk_maxed")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var o: OwnerProfile = ctx.state.owner
	var ranks: Dictionary[StringName, int] = o.perks.duplicate()
	ranks[perk_id] = ranks.get(perk_id, 0) + 1
	o.perks.clear()
	for k: StringName in GameState.sorted_names(ranks):
		o.perks[k] = ranks[k]
	o.skill_points -= 1
	var def: PerkDef = ctx.content.perks[perk_id]
	var owner_staff: Staff = ctx.state.staff.get(o.staff_id)
	if owner_staff == null:
		return
	for effect: StringName in GameState.sorted_names(def.effects_bp_per_rank):
		if effect.begins_with("skill_"):
			var skill: StringName = StringName(effect.trim_prefix("skill_"))
			owner_staff.skills[skill] = clampi(owner_staff.skills.get(skill, 0)
				+ Fixed.mul_bp(100, def.effects_bp_per_rank[effect]), 0, 100)
