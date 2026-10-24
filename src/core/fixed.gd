class_name Fixed
extends RefCounted
## Fixed-point helpers. GameState holds no floats; ratios are basis points (ONE_BP = 1.0).

const ONE_BP: int = 10000

## value * bp / ONE_BP, truncated toward zero (-10.5 -> -10). Safe while |value * bp| < 2^63.
static func mul_bp(value: int, bp: int) -> int:
	@warning_ignore("integer_division")
	return value * bp / ONE_BP

## True with probability chance_bp / ONE_BP. Exactly one rng draw.
static func roll_bp(rng: RandomNumberGenerator, chance_bp: int) -> bool:
	return rng.randi_range(0, ONE_BP - 1) < chance_bp
