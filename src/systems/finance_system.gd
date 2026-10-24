class_name FinanceSystem
extends RefCounted


static func tick(ctx: TickContext) -> void:
	var state: GameState = ctx.state
	if not Calendar.is_month_start(state.week, ctx.tuning):
		return
	for company_id: int in state.sorted_ids(state.companies):
		var payroll: int = 0
		for staff_id: int in state.staff_of(company_id):
			payroll += state.staff[staff_id].salary
		if payroll == 0:
			continue
		var company: Company = state.companies[company_id]
		company.money -= payroll
		ctx.emit(&"money_changed", {"company_id": company_id, "money": company.money})
