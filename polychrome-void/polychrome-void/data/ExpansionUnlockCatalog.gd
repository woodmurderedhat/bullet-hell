## ExpansionUnlockCatalog — deterministic expansion unlock list for runtime systems.
## Uses explicit preloads so exported builds (including web) don't rely on DirAccess.
class_name ExpansionUnlockCatalog
extends RefCounted

const _UNLOCK_RESOURCES: Array[Resource] = [
	preload("res://data/expansions/arena_profile_b.tres"),
	preload("res://data/expansions/arena_profile_c.tres"),
	preload("res://data/expansions/arena_profile_d.tres"),
	preload("res://data/expansions/boss_tier_1_a.tres"),
	preload("res://data/expansions/boss_tier_1_b.tres"),
	preload("res://data/expansions/boss_tier_2_a.tres"),
	preload("res://data/expansions/boss_tier_2_b.tres"),
	preload("res://data/expansions/boss_tier_3_a.tres"),
	preload("res://data/expansions/damage_tier_1.tres"),
	preload("res://data/expansions/damage_tier_2.tres"),
	preload("res://data/expansions/damage_tier_3.tres"),
	preload("res://data/expansions/damage_tier_4.tres"),
	preload("res://data/expansions/damage_tier_5.tres"),
	preload("res://data/expansions/elite_flanker.tres"),
	preload("res://data/expansions/elite_hunter.tres"),
	preload("res://data/expansions/elite_interceptor.tres"),
	preload("res://data/expansions/elite_splitter.tres"),
	preload("res://data/expansions/elite_suppressor.tres"),
	preload("res://data/expansions/elite_zoner.tres"),
	preload("res://data/expansions/enemy_pack_1.tres"),
	preload("res://data/expansions/enemy_pack_2.tres"),
	preload("res://data/expansions/enemy_pack_3.tres"),
	preload("res://data/expansions/enemy_pack_4.tres"),
	preload("res://data/expansions/enemy_pack_5.tres"),
	preload("res://data/expansions/enemy_pack_6.tres"),
	preload("res://data/expansions/enemy_pack_7.tres"),
	preload("res://data/expansions/enemy_pack_8.tres"),
	preload("res://data/expansions/intel_tier_1.tres"),
	preload("res://data/expansions/intel_tier_2.tres"),
	preload("res://data/expansions/intel_tier_3.tres"),
	preload("res://data/expansions/intel_tier_4.tres"),
	preload("res://data/expansions/intel_tier_5.tres"),
	preload("res://data/expansions/mod_pack_overclock.tres"),
	preload("res://data/expansions/mod_pack_pincer.tres"),
	preload("res://data/expansions/mod_pack_pressure.tres"),
	preload("res://data/expansions/mod_pack_swarm.tres"),
]


static func get_all_unlocks() -> Array[ExpansionUnlockResource]:
	var unlocks: Array[ExpansionUnlockResource] = []
	for loaded: Resource in _UNLOCK_RESOURCES:
		if loaded is ExpansionUnlockResource:
			unlocks.append(loaded as ExpansionUnlockResource)
	return unlocks


static func get_catalog_by_id() -> Dictionary:
	var catalog: Dictionary = {}
	for unlock_res: ExpansionUnlockResource in get_all_unlocks():
		catalog[unlock_res.id] = unlock_res
	return catalog
