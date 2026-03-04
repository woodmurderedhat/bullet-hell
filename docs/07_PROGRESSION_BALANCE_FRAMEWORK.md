# Progression & Balance

## Core Run Scaling

- Enemy HP scaling: `base_hp * (1 + arena_index * 0.12)`
- Boss HP scaling: `base_hp * (1 + arena_index * 0.12)`
- Enemy count baseline: `4 + arena_index * 2`
- Spawn interval baseline: `max(0.4, 1.2 - arena_index * 0.05)`

## Arena Length & Boss Cadence

- Arena 1 length: `25` levels
- Per-arena growth: `+10` levels each subsequent arena
- Arena length formula: `25 + (arena_number - 1) * 10`
- Standard mode clear target: `90` total levels (through Arena 3)
- Boss cadence: every `5` levels using internal level-index cadence (`5, 10, 15, ...`)

## Upgrade Offer Distribution

- Common 60%
- Rare 25%
- Epic 10%
- Legendary 5%

Synergy bias increases draw chance by 15% per dominant tag.

## Meta Progression Model (Expansion-First)

Meta rewards no longer focus on direct player-strength unlocks. Purchased expansion unlocks are persistent and can be toggled active per run.

### Expansion Categories

- Boss roster tiers
- Enemy pack tiers
- Elite archetype unlocks
- Damage tiers (enemy + boss)
- Intelligence tiers (AI pressure and prediction)
- Arena profile tiers
- Challenge mod packs

### Tier Conventions

- Damage tiers are mutually exclusive (`damage_tier` group).
- Intelligence tiers are mutually exclusive (`intel_tier` group).
- Arena profiles are mutually exclusive (`arena_profile` group).
- Boss/enemy packs and archetypes are additive.

### First-Pass Cost Curve (Meta Currency)

- Enemy packs: 40 → 220
- Boss tiers: 80 → 320
- Elite archetypes: 90 → 230
- Damage tiers: 60 → 280
- Intelligence tiers: 70 → 310
- Arena profiles: 100 → 260
- Challenge packs: 140 → 300

## Runtime Effect Composition

Active expansion unlocks are composed into a runtime profile that feeds encounter systems:

- Aggregate roster additions (`enemy_resource_paths`, `boss_resource_paths`)
- Multipliers (`enemy_hp`, `boss_hp`, `enemy_damage`, `boss_damage`)
- Pressure controls (`enemy_count_add`, `spawn_interval_scale`)
- Intelligence selection (`intelligence_tier`)
- Elite activation (`elite_archetypes`)
- Arena bounds profile (`arena_min`, `arena_max`)