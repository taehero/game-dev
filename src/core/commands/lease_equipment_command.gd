class_name LeaseEquipmentCommand
extends BuyEquipmentCommand
## Same checks as a purchase except money; the lease is charged monthly by FinanceSystem.


func _init(p_company_id: int, p_def_id: StringName, p_seat_index: int) -> void:
	super(p_company_id, p_def_id, p_seat_index)
	_leased = true
