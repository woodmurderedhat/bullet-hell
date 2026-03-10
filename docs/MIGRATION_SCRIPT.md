# Migration Script Documentation

## Overview

The migration script (`migrate_sprites.py`) automates the transition from the old sprite schema to the new per-state sprite system. It updates Godot resource (`.tres`) files to reference sprite paths for all four animation states (idle, move, hit, death).

**Location**: [`migrate_sprites.py`](migrate_sprites.py)

## Purpose

The old sprite system stored a single sprite texture per entity:
```python
# Old schema
sprite_texture_path = "res://assets/sprites/enemy.png"
```

The new system supports per-state sprites for animations:
```python
# New schema
sprite_idle_path = "res://assets/sprites/enemies/basic_1/basic_1_idle.png"
sprite_move_path = "res://assets/sprites/enemies/basic_1/basic_1_move.png"
sprite_hit_path = "res://assets/sprites/enemies/basic_1/basic_1_hit.png"
sprite_death_path = "res://assets/sprites/enemies/basic_1/basic_1_death.png"
hit_state_duration = 0.1
death_state_duration = 0.25
```

## Usage

### Basic Usage

```bash
python3 migrate_sprites.py
```

The script will:
1. Scan `polychrome-void/polychrome-void/data/enemies/` for `.tres` files
2. Scan `polychrome-void/polychrome-void/data/bosses/` for `.tres` files
3. Apply the sprite mapping transformations
4. Output results to console

### Prerequisites

1. Generate sprites using the [Sprite Generator](SPRITE_GENERATOR.md)
2. Ensure `.tres` files exist in the data directories

## Configuration

### Sprite Mappings

The script uses dictionaries to map entity IDs to sprite set folders:

#### Enemy Mapping

```python
ENEMY_SPRITE_MAPPING: dict[str, str] = {
    "basic_square":         "basic_1",
    "burst_square":         "basic_2",
    "dash_spike":           "basic_3",
    "kiting_shard":         "basic_4",
    "strafer_diamond":      "basic_4",
    "sentry_core":          "basic_5",
    "dash_burst_brute":     "medium_1",
    "strafe_spiral_node":   "medium_1",
    "elite_flanker_01":     "medium_2",
    "elite_flanker_02":     "medium_2",
    "orbit_burst_node":     "medium_2",
    "orbit_hex":            "medium_3",
    "elite_interceptor_01": "medium_3",
    "apex_orbit_01":        "medium_3",
    "wave_kite":            "medium_4",
    "elite_zoner_01":       "medium_4",
    "apex_kiting_01":       "medium_4",
    "elite_splitter_01":    "medium_1",
    "elite_hunter_01":      "heavy_1",
    "apex_dash_01":         "heavy_1",
    "elite_suppressor_01":  "heavy_2",
    "apex_sentry_01":       "heavy_2",
    "apex_zigzag_01":       "heavy_3",
}
```

#### Boss Mapping

```python
BOSS_SPRITE_MAPPING: dict[str, str] = {
    "boss_01": "boss_1",
    "boss_02": "boss_1",
    "boss_03": "boss_1",
    "boss_04": "boss_1",
    "boss_05": "boss_2",
    "boss_06": "boss_2",
    "boss_07": "boss_2",
    "boss_08": "boss_2",
}
```

### Adding New Mappings

To add new entity mappings:

1. Open [`migrate_sprites.py`](migrate_sprites.py)
2. Add entries to `ENEMY_SPRITE_MAPPING` or `BOSS_SPRITE_MAPPING`:
   ```python
   "your_entity_id": "sprite_folder_name",
   ```
3. Run the migration script

## What the Script Does

### 1. Extracts Entity ID

The script reads each `.tres` file and extracts the entity ID using regex:
```python
_id_RE = re.compile(r'^id\s*=\s*&"([^"]+)"', re.MULTILINE)
```

### 2. Maps to Sprite Set

The entity ID is looked up in the mapping dictionary to find the corresponding sprite folder.

### 3. Removes Old Fields

Removes any existing sprite-related fields to prevent conflicts:
- `sprite_texture_path`
- `sprite_region_origin`
- `sprite_frame_count`
- `sprite_fps`
- `sprite_idle_path`
- `sprite_move_path`
- `sprite_hit_path`
- `sprite_death_path`
- `hit_state_duration`
- `death_state_duration`

### 4. Inserts New Fields

Adds the new per-state sprite paths before the first anchor field (`score_value` or `phases`):

```python
sprite_idle_path = "res://assets/sprites/enemies/basic_1/basic_1_idle.png"
sprite_move_path = "res://assets/sprites/enemies/basic_1/basic_1_move.png"
sprite_hit_path = "res://assets/sprites/enemies/basic_1/basic_1_hit.png"
sprite_death_path = "res://assets/sprites/enemies/basic_1/basic_1_death.png"
hit_state_duration = 0.1
death_state_duration = 0.25
```

## Output Example

```
=== Migrating enemy .tres files ===
  OK  [basic_square               → basic_1]  basic_square.tres
  OK  [burst_square               → basic_2]  burst_square.tres
  OK  [dash_spike                 → basic_3]  dash_spike.tres
  SKIP (unmapped id 'new_enemy'): new_enemy.tres

=== Migrating boss .tres files ===
  OK  [boss_01                    → boss_1]  boss_01.tres
  OK  [boss_05                    → boss_2]  boss_05.tres

Done.
```

## Troubleshooting

### "SKIP (unmapped id)" Message

The entity ID is not in the mapping dictionary. Add the entity to the appropriate mapping dictionary.

### "SKIP (no id field)" Message

The `.tres` file doesn't have an `id` field, or it's not in the expected format.

### File Not Modified

The script writes changes immediately. If no changes occur:
1. Check that the entity ID matches exactly
2. Verify the `.tres` file exists in the correct directory

## Rollback

To rollback changes:
1. Use version control (git)
2. Manually restore the `.tres` files from backup

## Related Documentation

- [Sprite Generator](SPRITE_GENERATOR.md) - Generate the sprites
- [Sprite Migration Plan](14_SPRITE_MIGRATION_PLAN_32x32.md) - Migration phases
- [Main README](../README.md) - Project overview
