# Content Data Schema

## Upgrade Resource
- id
- rarity
- tags
- stat_additive
- stat_multiplicative
- triggers
- stack_limit

## Enemy Resource
- id
- base_hp
- speed
- collision_radius
- pattern
- movement_type
- lateral_weight
- preferred_range
- dash_interval
- dash_duration
- dash_speed_multiplier
- wave_frequency
- wave_amplitude
- color
- score_value

## Pattern Resource
- id
- fire_rate
- bullet_speed

### Spiral Pattern Resource
- angle_step
- arms

### Radial Burst Pattern Resource
- bullet_count
- burst_interval

### Arc Pattern Resource
- burst_interval
- bullet_count
- arc_degrees
- sweep_step

### Cross Pattern Resource
- burst_interval
- angle_offset

## Boss Phase Resource
- hp_threshold
- pattern
- speed_multiplier
- phase_color

## Boss Resource
- id
- base_hp
- speed
- collision_radius
- base_color
- score_value
- phases

## Expansion Unlock Resource
- id
- display_name
- description
- category
- cost
- required_unlock_ids
- mutually_exclusive_group
- enemy_resource_paths
- boss_resource_paths
- enemy_hp_multiplier
- boss_hp_multiplier
- enemy_damage_multiplier
- boss_damage_multiplier
- enemy_count_add
- spawn_interval_scale
- intelligence_tier
- elite_archetype
- arena_min
- arena_max

## Save Keys (Progression)
- meta_currency
- expansion_unlocks
- active_expansion_unlocks
- high_score
- leaderboard_scores
- runs_completed