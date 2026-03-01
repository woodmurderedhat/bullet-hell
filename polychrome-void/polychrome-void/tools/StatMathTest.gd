## StatMathTest — unit test for ModifierComponent.get_stat() math.
## Run from the editor (Scene > Run Specific Scene) or via GUT/doctest.
## Prints PASS / FAIL for each assertion to the Output tab.
extends Node

const EPSILON: float = 0.001


func _ready() -> void:
	print("[StatMathTest] Running...")
	_run_all()
	print("[StatMathTest] Done.")


func _run_all() -> void:
	_test_additive_only()
	_test_multiplicative_only()
	_test_combined()
	_test_stack_limit()


func _test_additive_only() -> void:
	var mc: ModifierComponent = ModifierComponent.new()
	var res: UpgradeResource = _make_upgrade({"bullet_damage": 5.0}, {}, 5)
	mc.apply_upgrade(res)
	mc.apply_upgrade(res)  # Stack ×2.
	var result: float = mc.get_stat(10.0, &"bullet_damage")
	# Expected: (10 + 5 + 5) * 1.0 = 20.0
	_assert_approx(result, 20.0, "additive_only stackx2")
	mc.free()


func _test_multiplicative_only() -> void:
	var mc: ModifierComponent = ModifierComponent.new()
	var res: UpgradeResource = _make_upgrade({}, {"speed": 1.2}, 5)
	mc.apply_upgrade(res)
	mc.apply_upgrade(res)  # Stack ×2 → 1.2 * 1.2 = 1.44.
	var result: float = mc.get_stat(100.0, &"speed")
	# Expected: (100 + 0) * 1.44 = 144.0
	_assert_approx(result, 144.0, "multiplicative_only stackx2")
	mc.free()


func _test_combined() -> void:
	var mc: ModifierComponent = ModifierComponent.new()
	var res: UpgradeResource = _make_upgrade({"bullet_damage": 5.0}, {"bullet_damage": 1.1}, 5)
	mc.apply_upgrade(res)
	var result: float = mc.get_stat(10.0, &"bullet_damage")
	# Expected: (10 + 5) * 1.1 = 16.5
	_assert_approx(result, 16.5, "combined additive+multiplicative")
	mc.free()


func _test_stack_limit() -> void:
	var mc: ModifierComponent = ModifierComponent.new()
	var res: UpgradeResource = _make_upgrade({"fire_rate": 1.0}, {}, 2)
	mc.apply_upgrade(res)
	mc.apply_upgrade(res)
	mc.apply_upgrade(res)  # Third should be rejected.
	var result: float = mc.get_stat(5.0, &"fire_rate")
	# Expected: (5 + 1 + 1) * 1.0 = 7.0  (third application rejected)
	_assert_approx(result, 7.0, "stack_limit respected")
	mc.free()


## Create a minimal UpgradeResource for testing.
func _make_upgrade(add: Dictionary, mul: Dictionary, stack: int) -> UpgradeResource:
	var res: UpgradeResource = UpgradeResource.new()
	res.id = &"_test_upgrade"
	res.stat_additive = add
	res.stat_multiplicative = mul
	res.stack_limit = stack
	return res


func _assert_approx(actual: float, expected: float, label: String) -> void:
	if absf(actual - expected) < EPSILON:
		print("[StatMathTest] PASS  %s  (%.4f)" % [label, actual])
	else:
		push_error("[StatMathTest] FAIL  %s  expected=%.4f  got=%.4f" % [label, expected, actual])
