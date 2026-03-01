## RandomService — deterministic seeded random number generation.
## Wraps Godot's RandomNumberGenerator with an explicit seed so that
## gameplay logic is reproducible from a given seed value.
## Autoloaded as "RandomService".
extends Node

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	# Default seed randomised at startup; call set_seed() for determinism.
	_rng.randomize()


## Seed the generator for fully deterministic output.
func set_seed(s: int) -> void:
	_rng.seed = s


## Returns the current seed so it can be saved/replayed.
func get_seed() -> int:
	return _rng.seed


## Returns a random float in [0.0, 1.0).
func next_float() -> float:
	return _rng.randf()


## Returns a random integer in [from, to] (inclusive).
func next_int_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Weighted random pick.
## weights must be a parallel Array[float] with the same length as items.
## Returns one element from items, or null if arrays are empty.
##
## Example:
##   weighted_pick(["a","b","c"], [60.0, 25.0, 15.0])
func weighted_pick(items: Array, weights: Array[float]) -> Variant:
	assert(items.size() == weights.size(), "RandomService: items/weights length mismatch")
	if items.is_empty():
		return null

	var total: float = 0.0
	for w: float in weights:
		total += w

	var roll: float = _rng.randf() * total
	var cumulative: float = 0.0
	for i: int in range(items.size()):
		cumulative += weights[i]
		if roll < cumulative:
			return items[i]

	# Fallback (floating-point edge case).
	return items[items.size() - 1]
