class_name SellEquipmentCommand
extends Command

var equipment_id: int


func _init(p_equipment_id: int) -> void:
	equipment_id = p_equipment_id


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	if not state.equipment.has(equipment_id) or state.equipment[equipment_id].company_id != state.player_company_id:
		return CommandResult.fail(&"error.equipment_not_found")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var e: Equipment = ctx.state.equipment[equipment_id]
	var company: Company = ctx.state.companies[e.company_id]
	var sold: bool = e.ownership == Equipment.Ownership.BOUGHT
	if sold:
		company.money += e.value
	Removal.remove_equipment(ctx.state, equipment_id)
	ctx.emit(&"equipment_changed", {"equipment_id": equipment_id})
	if sold:
		ctx.emit(&"money_changed", {"company_id": company.id, "money": company.money})
