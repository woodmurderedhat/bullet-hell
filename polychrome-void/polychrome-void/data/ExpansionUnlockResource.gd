## ExpansionUnlockResource — meta-progression unlock that expands encounter scope.
## These unlocks are purchased permanently, then toggled active per run.
class_name ExpansionUnlockResource
extends Resource

enum Category {
	BOSS_ROSTER,
	ENEMY_ROSTER,
	ELITE_ARCHETYPE,
	DAMAGE_TIER,
	INTELLIGENCE_TIER,
	ARENA_PROFILE,
	CHALLENGE_MOD,
}

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var category: Category = Category.ENEMY_ROSTER
@export var cost: int = 50
@export var required_unlock_ids: Array[StringName] = []
@export var mutually_exclusive_group: StringName = &""

@export var enemy_resource_paths: Array[String] = []
@export var boss_resource_paths: Array[String] = []

@export var enemy_hp_multiplier: float = 1.0
@export var boss_hp_multiplier: float = 1.0
@export var enemy_damage_multiplier: float = 1.0
@export var boss_damage_multiplier: float = 1.0
@export var enemy_count_add: int = 0
@export var spawn_interval_scale: float = 1.0
@export var intelligence_tier: int = 0
@export var elite_archetype: StringName = &""

@export var arena_min: Vector2 = Vector2(40.0, 40.0)
@export var arena_max: Vector2 = Vector2(1240.0, 680.0)
