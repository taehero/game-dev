extends GutTest

func test_mul_bp_scales_and_truncates_toward_zero() -> void:
	assert_eq(Fixed.mul_bp(1000, 15000), 1500)
	assert_eq(Fixed.mul_bp(7, 15000), 10)
	assert_eq(Fixed.mul_bp(-7, 15000), -10)

func test_roll_bp_bounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 200:
		assert_false(Fixed.roll_bp(rng, 0))
		assert_true(Fixed.roll_bp(rng, Fixed.ONE_BP))
