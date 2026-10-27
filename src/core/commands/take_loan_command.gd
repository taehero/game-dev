class_name TakeLoanCommand
extends Command

var company_id: int
var lender_id: int
var amount: int


func _init(p_company_id: int, p_lender_id: int, p_amount: int) -> void:
	company_id = p_company_id
	lender_id = p_lender_id
	amount = p_amount


func validate(state: GameState, tuning: TuningDef) -> CommandResult:
	if not state.companies.has(company_id):
		return CommandResult.fail(&"error.company_not_found")
	if not state.companies.has(lender_id) or not [Company.Kind.BANK, Company.Kind.LENDER].has(state.companies[lender_id].kind):
		return CommandResult.fail(&"error.lender_not_found")
	if amount <= 0:
		return CommandResult.fail(&"error.invalid_amount")
	if state.companies[lender_id].kind == Company.Kind.BANK and MoneyRules.bank_refuses(state, company_id, tuning):
		return CommandResult.fail(&"error.bank_refused")
	if amount > MoneyRules.available_credit(state, company_id, lender_id, tuning):
		return CommandResult.fail(&"error.over_credit_limit")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var l := Loan.new()
	l.id = ctx.state.alloc_id()
	l.company_id = company_id
	l.lender_id = lender_id
	l.principal = amount
	l.balance = amount
	l.rate_bp_per_month = MoneyRules.loan_rate_bp(ctx.state, ctx.content, lender_id, ctx.tuning)
	l.payment_per_month = (amount + ctx.tuning.loan_term_months - 1) / ctx.tuning.loan_term_months
	l.taken_week = ctx.state.week
	ctx.state.loans[l.id] = l
	var company: Company = ctx.state.companies[company_id]
	company.money += amount
	ctx.emit(&"loan_taken", {"loan_id": l.id})
	ctx.emit(&"money_changed", {"company_id": company_id, "money": company.money})
