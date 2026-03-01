## ModifierComponent — accumulates stat modifiers from applied upgrades.
## Attach as a child of Player. Player polls get_stat() each time it needs a value.
## No signals emitted; all reads are synchronous polls.
class_name ModifierComponent
extends Node

## Tracks how many times each upgrade id has been stacked.
var _stack_counts: Dictionary = {}

## Flat additive delta per stat key.
var _additive: Dictionary = {}

## Multiplicative scalar per stat key (defaults to 1.0).
var _multiplicative: Dictionary = {}

## Active trigger IDs (used by Player/enemies to resolve special behaviour).
var _triggers: Array[StringName] = []


## Apply an upgrade resource.  Respects stack_limit.
func apply_upgrade(res: UpgradeResource) -> void:
	var id_str: String = str(res.id)
	var current_stacks: int = _stack_counts.get(id_str, 0)
	if current_stacks >= res.stack_limit:
		return

	_stack_counts[id_str] = current_stacks + 1

	for key in res.stat_additive.keys():
		_additive[key] = _additive.get(key, 0.0) + float(res.stat_additive[key])

	for key in res.stat_multiplicative.keys():
		_multiplicative[key] = _multiplicative.get(key, 1.0) * float(res.stat_multiplicative[key])

	for trigger: StringName in res.triggers:
		if not _triggers.has(trigger):
			_triggers.append(trigger)


## Returns the effective value for a stat.
## Formula: (base + additive) * multiplicative
func get_stat(base: float, key: StringName) -> float:
	var add: float = _additive.get(str(key), 0.0)
	var mul: float = _multiplicative.get(str(key), 1.0)
	return (base + add) * mul


## Returns true if the given trigger is active.
func has_trigger(trigger: StringName) -> bool:
	return _triggers.has(trigger)


## Collect all active archetype tags from applied upgrades.
## Used by UpgradePool to compute synergy bias.
func get_active_tags(upgrade_pool_resource: Array) -> Array[StringName]:
	var tags: Array[StringName] = []
	for id_str: String in _stack_counts.keys():
		for res: UpgradeResource in upgrade_pool_resource:
			if str(res.id) == id_str:
				for tag: StringName in res.tags:
					if not tags.has(tag):
						tags.append(tag)
	return tags


## Reset all modifiers (called at the start of a new run).
func reset() -> void:
	_stack_counts.clear()
	_additive.clear()
	_multiplicative.clear()
	_triggers.clear()
