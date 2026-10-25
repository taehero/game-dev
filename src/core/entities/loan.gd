class_name Loan
extends RefCounted

const SCHEMA: Dictionary = {
	"id": "int",
	"company_id": "int",
	"lender_id": "int",
	"principal": "int",
	"balance": "int",
	"rate_bp_per_month": "int",
	"payment_per_month": "int",
	"missed_payments": "int",
	"taken_week": "int",
}

var id: int
var company_id: int
var lender_id: int
var principal: int = 0
var balance: int = 0
var rate_bp_per_month: int = 0
var payment_per_month: int = 0
var missed_payments: int = 0
var taken_week: int = 0


func to_dict() -> Dictionary:
	return {
		"id": id,
		"company_id": company_id,
		"lender_id": lender_id,
		"principal": principal,
		"balance": balance,
		"rate_bp_per_month": rate_bp_per_month,
		"payment_per_month": payment_per_month,
		"missed_payments": missed_payments,
		"taken_week": taken_week,
	}


static func from_dict(d: Dictionary) -> Loan:
	var l := Loan.new()
	l.id = int(d["id"])
	l.company_id = int(d["company_id"])
	l.lender_id = int(d["lender_id"])
	l.principal = int(d["principal"])
	l.balance = int(d["balance"])
	l.rate_bp_per_month = int(d["rate_bp_per_month"])
	l.payment_per_month = int(d["payment_per_month"])
	l.missed_payments = int(d["missed_payments"])
	l.taken_week = int(d["taken_week"])
	return l
