## UpgradeResource — data definition for a single upgrade card.
## Create .tres instances in res://data/upgrades/
class_name UpgradeResource
extends Resource

## Archetype tag enum matching the nine design-doc tags.
enum Rarity { COMMON = 0, RARE = 1, EPIC = 2, LEGENDARY = 3 }

## Unique string key for this upgrade.
@export var id: StringName = &""

## Rarity tier governs draw weight.
@export var rarity: Rarity = Rarity.COMMON

## Archetype tags for synergy-bias and build identity.
@export var tags: Array[StringName] = []

## Flat additive stat deltas applied via ModifierComponent.
## Keys must match PlayerStats field names (e.g. "bullet_damage", "speed").
@export var stat_additive: Dictionary = {}

## Multiplicative stat scalars (1.0 = no change, 1.1 = +10%).
@export var stat_multiplicative: Dictionary = {}

## Trigger IDs this upgrade activates (resolved by ModifierComponent).
@export var triggers: Array[StringName] = []

## Maximum times this upgrade can be stacked in a single run.
@export var stack_limit: int = 5

## Human-readable display name shown in the upgrade picker UI.
@export var display_name: String = ""

## Brief description shown on the upgrade card.
@export var description: String = ""
