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

## Trigger stack counts by trigger id.
var _trigger_counts: Dictionary = {}


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
		var trigger_str: String = str(trigger)
		_trigger_counts[trigger_str] = int(_trigger_counts.get(trigger_str, 0)) + 1
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
	return get_trigger_stack(trigger) > 0


## Returns the number of stacks owned for a specific upgrade id.
func get_upgrade_stack(upgrade_id: StringName) -> int:
	return int(_stack_counts.get(str(upgrade_id), 0))


## Returns the number of stacks owned for a specific trigger id.
func get_trigger_stack(trigger: StringName) -> int:
	return int(_trigger_counts.get(str(trigger), 0))


## Checks whether an upgrade can currently be applied.
## Used by UpgradePool to gate offers by prerequisites and stack limits.
func can_apply_upgrade(res: UpgradeResource) -> bool:
	if get_upgrade_stack(res.id) >= res.stack_limit:
		return false

	for prerequisite: StringName in res.prerequisites:
		if get_upgrade_stack(prerequisite) <= 0:
			return false

	for key: Variant in res.required_upgrade_stacks.keys():
		var required_id: StringName = StringName(str(key))
		var required_stacks: int = int(res.required_upgrade_stacks[key])
		if get_upgrade_stack(required_id) < required_stacks:
			return false

	return true


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
	_trigger_counts.clear()
