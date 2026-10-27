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
		if has_office and e.ownership == Equipment.Ownership.LEASED:
			leases += def.lease_per_month
	return {
		"salaries": salaries,
		"rent": rent,
		"electricity": electricity,
		"leases": leases,
		"total": salaries + rent + electricity + leases,
	}


static func bank_refuses(state: GameState, company_id: int, t: TuningDef) -> bool:
	var last: int = state.companies[company_id].last_missed_week
	return last >= 0 and state.week - last < t.bank_refuse_weeks


static func credit_limit(state: GameState, company_id: int, lender_id: int, t: TuningDef) -> int:
	if not state.companies.has(lender_id):
		return 0
	match state.companies[lender_id].kind:
		Company.Kind.BANK:
			if bank_refuses(state, company_id, t):
				return 0
			return t.bank_limit_base + state.companies[company_id].reputation * t.bank_limit_per_rep
		Company.Kind.LENDER:
			return t.shark_limit
	return 0


static func available_credit(state: GameState, company_id: int, lender_id: int, t: TuningDef) -> int:
	var owed: int = 0
	for lid: int in state.sorted_ids(state.loans):
		var l: Loan = state.loans[lid]
		if l.company_id == company_id and l.lender_id == lender_id:
			owed += l.balance
	return maxi(0, credit_limit(state, company_id, lender_id, t) - owed)


static func has_credit(state: GameState, company_id: int, t: TuningDef) -> bool:
	for cid: int in state.sorted_ids(state.companies):
		var k: Company.Kind = state.companies[cid].kind
		if (k == Company.Kind.BANK or k == Company.Kind.LENDER) and available_credit(state, company_id, cid, t) > 0:
			return true
	return false


static func loan_rate_bp(state: GameState, content: ContentDB, lender_id: int, t: TuningDef) -> int:
	if state.companies[lender_id].kind == Company.Kind.LENDER:
		return t.shark_rate_bp_per_month
	return maxi(0, Fixed.mul_bp(t.bank_rate_bp_per_month, Fixed.ONE_BP + PeopleRules.effect_bp(state, content, &"loan_rate_bp")))
