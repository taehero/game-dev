extends GutTest

var t := Fixtures.tuning()


func test_year_from_week() -> void:
	assert_eq(Calendar.year(0, t), 1980)
	assert_eq(Calendar.year(51, t), 1980)
	assert_eq(Calendar.year(52, t), 1981)
	assert_eq(Calendar.year(519, t), 1989)


func test_twelve_month_starts_per_year() -> void:
	var n := 0
	for w in 52:
		if Calendar.is_month_start(w, t):
			n += 1
	assert_eq(n, 12)


func test_four_quarter_starts_per_year() -> void:
	var starts: Array = [0, 13, 26, 39].filter(
		func(w: int) -> bool: return Calendar.is_quarter_start(w, t)
	)
	assert_eq(starts.size(), 4)
	assert_false(Calendar.is_quarter_start(14, t))


func test_week_in_year_wraps() -> void:
	assert_eq(Calendar.week_in_year(53, t), 1)
