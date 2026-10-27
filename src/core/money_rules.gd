class_name MoneyRules
extends RefCounted
## Monthly cost model. Pure functions of state; no RNG.


static func monthly_costs(state: GameState, content: ContentDB, company_id: int) -> Dictionary:
	var salaries: int = 0
	for staff_id: int in state.staff_of(company_id):
		salaries += state.staff[staff_id].salary
	var rent: int = 0
	var electricity: int = 0
	var leases: int = 0
	var office_id: StringName = state.companies[company_id].office_id
	var has_office: bool = content.offices.has(office_id)
	if has_office:
		rent = content.offices[office_id].rent_per_month
		electricity = content.offices[office_id].electricity_base
	for eid: int in state.sorted_ids(state.equipment):
		var e: Equipment = state.equipment[eid]
		if e.company_id != company_id or not content.equipment.has(e.def_id):
			continue
		var def: EquipmentDef = content.equipment[e.def_id]
		if has_office and e.seat_index >= 0:
			electricity += def.power_per_month
		if e.ownership == Equipment.Ownership.LEASED:
			leases += def.lease_per_month
	return {
		"salaries": salaries,
		"rent": rent,
		"electricity": electricity,
		"leases": leases,
		"total": salaries + rent + electricity + leases,
	}
