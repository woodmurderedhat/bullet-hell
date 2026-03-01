## UpgradePool — manages the draw pool for upgrade offers.
## Handles rarity weighting and synergy-bias per the Progression Balance Framework.
class_name UpgradePool
extends Node

## Rarity base weights (must match UpgradeResource.Rarity enum order).
const RARITY_WEIGHTS: Array[float] = [60.0, 25.0, 10.0, 5.0]

## Synergy bias added per dominant tag match.
const SYNERGY_BIAS: float = 15.0

## Pre-loaded full upgrade roster.
const ALL_UPGRADES: Array[String] = [
	"res://data/upgrades/vector_speed_01.tres",
	"res://data/upgrades/vector_speed_02.tres",
	"res://data/upgrades/vector_pierce_01.tres",
	"res://data/upgrades/orbit_shield_01.tres",
	"res://data/upgrades/orbit_shield_02.tres",
	"res://data/upgrades/orbit_rate_01.tres",
	"res://data/upgrades/pulse_damage_01.tres",
	"res://data/upgrades/pulse_damage_02.tres",
	"res://data/upgrades/pulse_aoe_01.tres",
	"res://data/upgrades/fractal_split_01.tres",
	"res://data/upgrades/fractal_split_02.tres",
	"res://data/upgrades/fractal_chain_01.tres",
	"res://data/upgrades/entropy_chaos_01.tres",
	"res://data/upgrades/entropy_chaos_02.tres",
	"res://data/upgrades/entropy_wild_01.tres",
	"res://data/upgrades/sustain_regen_01.tres",
	"res://data/upgrades/sustain_regen_02.tres",
	"res://data/upgrades/sustain_maxhp_01.tres",
	"res://data/upgrades/crit_chance_01.tres",
	"res://data/upgrades/crit_chance_02.tres",
	"res://data/upgrades/crit_multi_01.tres",
	"res://data/upgrades/shield_block_01.tres",
	"res://data/upgrades/shield_block_02.tres",
	"res://data/upgrades/shield_reflect_01.tres",
	"res://data/upgrades/chaos_reroll_01.tres",
	"res://data/upgrades/chaos_reroll_02.tres",
	"res://data/upgrades/chaos_gamble_01.tres",
]

var _all_resources: Array[UpgradeResource] = []
var _meta_unlocked: Array[StringName] = []


func _ready() -> void:
	_load_all()
	_sync_meta_unlocks()


func _load_all() -> void:
	_all_resources.clear()
	for path: String in ALL_UPGRADES:
		if ResourceLoader.exists(path):
			var res: Resource = load(path)
			if res is UpgradeResource:
				_all_resources.append(res as UpgradeResource)


func _sync_meta_unlocks() -> void:
	_meta_unlocked = []
	var raw: Array = SaveService.get_save("meta_unlocks", [])
	for id: Variant in raw:
		_meta_unlocked.append(StringName(str(id)))


## Generate `count` unique upgrade offers.
## dominant_tags should be the active archetype tags from ModifierComponent.
func generate_offer(count: int, dominant_tags: Array[StringName]) -> Array[UpgradeResource]:
	var available: Array[UpgradeResource] = _build_available_pool()
	if available.is_empty():
		return []

	var picked: Array[UpgradeResource] = []
	var pool_copy: Array[UpgradeResource] = available.duplicate()

	for _i: int in range(count):
		if pool_copy.is_empty():
			break
		var weights: Array[float] = _compute_weights(pool_copy, dominant_tags)
		var chosen: Variant = RandomService.weighted_pick(pool_copy, weights)
		if chosen == null:
			break
		picked.append(chosen as UpgradeResource)
		pool_copy.erase(chosen)

	return picked


## Build the pool of currently available upgrades.
## Filters by meta unlock requirements (if id is in ALL_UPGRADES but not unlocked,
## it is still included — unlocks only gate locked content injected by MetaMenu).
func _build_available_pool() -> Array[UpgradeResource]:
	var pool: Array[UpgradeResource] = []
	for res: UpgradeResource in _all_resources:
		pool.append(res)
	return pool


## Compute per-item draw weights combining rarity and synergy bias.
func _compute_weights(pool: Array[UpgradeResource], dominant_tags: Array[StringName]) -> Array[float]:
	var weights: Array[float] = []
	weights.resize(pool.size())
	for i: int in range(pool.size()):
		var res: UpgradeResource = pool[i]
		var w: float = RARITY_WEIGHTS[res.rarity]
		# Add synergy bias for each tag overlap.
		for tag: StringName in res.tags:
			if dominant_tags.has(tag):
				w += SYNERGY_BIAS
		weights[i] = w
	return weights
