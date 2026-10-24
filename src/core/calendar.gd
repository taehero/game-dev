class_name Calendar
extends RefCounted
## Week arithmetic. Weeks are 0-based; a year has t.weeks_per_year weeks.
## Months follow a 4-4-5 pattern per 13-week quarter.


@warning_ignore("integer_division")
static func year(week: int, t: TuningDef) -> int:
	return t.start_year + week / t.weeks_per_year


static func week_in_year(week: int, t: TuningDef) -> int:
	return week % t.weeks_per_year


static func is_month_start(week: int, t: TuningDef) -> bool:
	var w: int = week_in_year(week, t) % 13
	return w == 0 or w == 4 or w == 8


static func is_quarter_start(week: int, t: TuningDef) -> bool:
	return week_in_year(week, t) % 13 == 0
