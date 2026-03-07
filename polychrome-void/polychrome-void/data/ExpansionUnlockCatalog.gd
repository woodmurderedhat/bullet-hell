## ExpansionUnlockCatalog — deterministic expansion unlock list for runtime systems.
## Uses explicit preloads so exported builds (including web) don't rely on DirAccess.
class_name ExpansionUnlockCatalog
extends RefCounted

const _UNLOCK_RESOURCE_PATHS: Array[String] = [
	"res://data/expansions/arena_profile_b.tres",
	"res://data/expansions/arena_profile_c.tres",
	"res://data/expansions/arena_profile_d.tres",
	"res://data/expansions/boss_tier_1_a.tres",
	"res://data/expansions/boss_tier_1_b.tres",
	"res://data/expansions/boss_tier_2_a.tres",
	"res://data/expansions/boss_tier_2_b.tres",
	"res://data/expansions/boss_tier_3_a.tres",
	"res://data/expansions/damage_tier_1.tres",
	"res://data/expansions/damage_tier_2.tres",
	"res://data/expansions/damage_tier_3.tres",
	"res://data/expansions/damage_tier_4.tres",
	"res://data/expansions/damage_tier_5.tres",
	"res://data/expansions/elite_flanker.tres",
	"res://data/expansions/elite_hunter.tres",
	"res://data/expansions/elite_interceptor.tres",
	"res://data/expansions/elite_splitter.tres",
	"res://data/expansions/elite_suppressor.tres",
	"res://data/expansions/elite_zoner.tres",
	"res://data/expansions/enemy_pack_1.tres",
	"res://data/expansions/enemy_pack_2.tres",
	"res://data/expansions/enemy_pack_3.tres",
	"res://data/expansions/enemy_pack_4.tres",
	"res://data/expansions/enemy_pack_5.tres",
	"res://data/expansions/enemy_pack_6.tres",
	"res://data/expansions/enemy_pack_7.tres",
	"res://data/expansions/enemy_pack_8.tres",
	"res://data/expansions/intel_tier_1.tres",
	"res://data/expansions/intel_tier_2.tres",
	"res://data/expansions/intel_tier_3.tres",
	"res://data/expansions/intel_tier_4.tres",
	"res://data/expansions/intel_tier_5.tres",
	"res://data/expansions/mod_pack_overclock.tres",
	"res://data/expansions/mod_pack_pincer.tres",
	"res://data/expansions/mod_pack_pressure.tres",
	"res://data/expansions/mod_pack_swarm.tres",
]


static func get_all_unlocks() -> Array[ExpansionUnlockResource]:
	var unlocks: Array[ExpansionUnlockResource] = []
	for path: String in _UNLOCK_RESOURCE_PATHS:
		if not ResourceLoader.exists(path):
			push_warning("ExpansionUnlockCatalog: missing resource path %s" % path)
			continue
		var loaded: Resource = load(path)
		if loaded is ExpansionUnlockResource:
			unlocks.append(loaded as ExpansionUnlockResource)
			continue
		var script_ref: Variant = loaded.get_script()
		if script_ref is Script and (script_ref as Script).resource_path == "res://data/ExpansionUnlockResource.gd":
			var casted: ExpansionUnlockResource = loaded as ExpansionUnlockResource
			if casted != null:
				unlocks.append(casted)
				continue
		push_warning("ExpansionUnlockCatalog: resource is not ExpansionUnlockResource %s" % path)
	return unlocks


static func get_catalog_by_id() -> Dictionary:
	var catalog: Dictionary = {}
	for unlock_res: ExpansionUnlockResource in get_all_unlocks():
		catalog[unlock_res.id] = unlock_res
	return catalog
