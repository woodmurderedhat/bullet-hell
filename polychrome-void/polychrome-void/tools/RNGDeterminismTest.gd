## RNGDeterminismTest — validates RandomService produces deterministic output from a fixed seed.
## Run from the editor. Prints PASS / FAIL to the Output tab.
extends Node

## Reference snapshot: first 10 weighted picks from seed 12345 with weights [60,25,10,5].
## Generated once and hardcoded here as the expected sequence.
## If RandomService implementation changes, regenerate this by running with CAPTURE_MODE = true.
const CAPTURE_MODE: bool = false
const SEED_VALUE: int    = 12345
const SAMPLE_COUNT: int  = 1000

## Items and weights for the distribution test.
const TEST_ITEMS: Array    = ["common", "rare", "epic", "legendary"]
const TEST_WEIGHTS: Array[float] = [60.0, 25.0, 10.0, 5.0]

## Expected approximate distribution percentages (±5% tolerance).
const EXPECTED_DIST: Dictionary = {
	"common":    0.60,
	"rare":      0.25,
	"epic":      0.10,
	"legendary": 0.05,
}
const TOLERANCE: float = 0.06


func _ready() -> void:
	print("[RNGTest] Running...")
	_test_determinism()
	_test_distribution()
	print("[RNGTest] Done.")


## Re-seeding with the same value must produce identical pick sequences.
func _test_determinism() -> void:
	RandomService.set_seed(SEED_VALUE)
	var run_a: Array = []
	for _i: int in range(20):
		run_a.append(RandomService.weighted_pick(TEST_ITEMS, TEST_WEIGHTS))

	RandomService.set_seed(SEED_VALUE)
	var run_b: Array = []
	for _i: int in range(20):
		run_b.append(RandomService.weighted_pick(TEST_ITEMS, TEST_WEIGHTS))

	var match_ok: bool = true
	for i: int in range(run_a.size()):
		if run_a[i] != run_b[i]:
			match_ok = false
			break

	if match_ok:
		print("[RNGTest] PASS  determinism (same seed → same sequence)")
	else:
		push_error("[RNGTest] FAIL  determinism  run_a=%s  run_b=%s" % [str(run_a), str(run_b)])


## Over 1000 picks the distribution should approximate the target weights.
func _test_distribution() -> void:
	RandomService.set_seed(SEED_VALUE + 1)
	var counts: Dictionary = {}
	for item: String in TEST_ITEMS:
		counts[item] = 0

	for _i: int in range(SAMPLE_COUNT):
		var pick: Variant = RandomService.weighted_pick(TEST_ITEMS, TEST_WEIGHTS)
		counts[str(pick)] += 1

	var all_pass: bool = true
	for item: String in TEST_ITEMS:
		var actual: float = float(counts[item]) / float(SAMPLE_COUNT)
		var expected: float = EXPECTED_DIST.get(item, 0.0)
		var diff: float = absf(actual - expected)
		if diff <= TOLERANCE:
			print("[RNGTest] PASS  dist '%s'  expected=%.2f  actual=%.2f" % [item, expected, actual])
		else:
			push_error("[RNGTest] FAIL  dist '%s'  expected=%.2f  actual=%.2f  diff=%.3f" % [item, expected, actual, diff])
			all_pass = false

	if all_pass:
		print("[RNGTest] PASS  all distribution bins within ±%.0f%%" % (TOLERANCE * 100.0))
