class_name RepayLoanCommand
extends Command

var loan_id: int
var amount: int


func _init(p_loan_id: int, p_amount: int) -> void:
	loan_id = p_loan_id
	amount = p_amount


func validate(state: GameState, _tuning: TuningDef) -> CommandResult:
	if not state.loans.has(loan_id) or state.loans[loan_id].company_id != state.player_company_id:
		return CommandResult.fail(&"error.loan_not_found")
	if amount <= 0 or amount > state.loans[loan_id].balance:
		return CommandResult.fail(&"error.invalid_amount")
	if state.companies[state.player_company_id].money < amount:
		return CommandResult.fail(&"error.not_enough_money")
	return CommandResult.success()


func apply(ctx: TickContext) -> void:
	var l: Loan = ctx.state.loans[loan_id]
	var company: Company = ctx.state.companies[l.company_id]
	company.money -= amount
	l.balance -= amount
	if l.balance == 0:
		Removal.remove_loan(ctx.state, loan_id)
	ctx.emit(&"money_changed", {"company_id": company.id, "money": company.money})
