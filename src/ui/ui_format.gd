class_name UiFormat
extends RefCounted
## Display number formatting. The only place that inserts thousands separators.


static func thousands(n: int) -> String:
	var digits: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "," + out
		out = digits[i] + out
		count += 1
	return ("-" + out) if n < 0 else out


## Score stored x10: 75 -> "7.5".
@warning_ignore("integer_division")
static func score(score_x10: int) -> String:
	return "%d.%d" % [score_x10 / 10, absi(score_x10) % 10]


static func signed(n: int) -> String:
	return ("+%d" % n) if n > 0 else str(n)


static func money(n: int) -> String:
	return TranslationServer.translate("ui.pill.currency") + thousands(n)
