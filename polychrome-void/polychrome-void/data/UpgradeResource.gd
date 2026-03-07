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

## Optional exclusive branch group id (e.g. "shield").
## If set, UpgradePool can lock offers to a chosen branch for this group.
@export var branch_group: StringName = &""

## Optional branch id within branch_group (e.g. "absorb", "repulse", "aura").
@export var branch_id: StringName = &""

## Required upgrade IDs that must already be owned before this can be offered.
@export var prerequisites: Array[StringName] = []

## Required stack thresholds for specific upgrade IDs.
## Example: {"fractal_split_01": 2} means that upgrade must be stacked twice.
@export var required_upgrade_stacks: Dictionary = {}

## Optional persistent meta unlock requirement.
## Empty value means this upgrade is always eligible in the pool.
@export var meta_unlock_required_id: StringName = &""

## Maximum times this upgrade can be stacked in a single run.
@export var stack_limit: int = 5

## Human-readable display name shown in the upgrade picker UI.
@export var display_name: String = ""

## Brief description shown on the upgrade card.
@export var description: String = ""
