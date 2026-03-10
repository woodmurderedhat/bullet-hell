# Polychrome Void - Bullet Hell Game

A high-performance bullet hell game built with Godot, designed to run at 60 FPS on Raspberry Pi 5 (1280x720) with support for 150 enemies, 4000 bullets, and 300 effects simultaneously.

## Project Overview

Polychrome Void is an abstract, high-contrast bullet hell game featuring:

- **Player-controlled spaceship** with rapid-fire weapons
- **Multiple enemy types**: Basic, Medium, and Heavy classifications
- **Boss battles** with phase transitions
- **Procedural bullet patterns** using MultiMesh rendering
- **Sprite-based visuals** (32x32 pixel art) with per-state animations

### Performance Targets

| Metric | Target |
|--------|--------|
| Resolution | 1280x720 |
| Frame Rate | 60 FPS |
| Max Enemies | 150 |
| Max Bullets | 4000 |
| Max Effects | 300 |
| Platform | Raspberry Pi 5, Web (HTML5) |

## Project Structure

```
bullet-hell/
├── docs/                           # Project documentation
│   └── 14_SPRITE_MIGRATION_PLAN_32x32.md
│
├── polychrome-void/                # Godot game project
│   └── polychrome-void/
│       ├── assets/
│       │   └── sprites/           # Game sprite assets
│       │       ├── bosses/        # Boss sprites
│       │       └── enemies/        # Enemy sprites
│       ├── audio/                 # Sound effects and music
│       ├── combat/                # Combat-related scripts
│       ├── core/                  # Core game systems
│       ├── data/                  # Game data resources
│       │   ├── bosses/           # Boss .tres files
│       │   ├── enemies/          # Enemy .tres files
│       │   ├── expansions/      # Expansion content
│       │   ├── patterns/         # Bullet patterns
│       │   └── upgrades/         # Player upgrades
│       ├── player/               # Player ship scripts
│       ├── scenes/               # Godot scenes
│       ├── systems/              # Game systems
│       ├── tools/                # Editor tools & tests
│       │   └── SpawnDistanceValidationTest.gd
│       └── ui/                   # User interface
│
├── spaceship-sprite-generator/    # Python sprite generation tool
│   ├── main.py                   # Entry point
│   ├── sprite_generator.py      # Core generation logic
│   └── requirements.txt          # Python dependencies (Pillow)
│
├── migrate_sprites.py            # Sprite data migration script
└── web/                          # Web export directory
```

## Visual Style

The game follows an **abstract, high-contrast, silhouette-first** visual language:

- **Dark background** for maximum contrast
- **Bold geometric shapes** for ships and enemies
- **Color-coded enemy tiers**:
  - Basic: Blues/Cyans (weaker enemies)
  - Medium: Greens/Yellows (mid-tier)
  - Heavy: Oranges/Reds (tough enemies)
  - Bosses: Purples/Magentas

## Sprite System

### Sprite States

Each sprite has four animation states:

| State | Description |
|-------|-------------|
| `idle` | Default standing animation |
| `move` | Movement state with thruster effects |
| `hit` | Damage flash state (0.1s duration) |
| `death` | Explosion/death animation (0.25s duration) |

### Sprite Dimensions

- **Canvas**: 32x32 pixels
- **Pivot**: Center for all actors
- **Filtering**: Nearest-neighbor (no mipmaps)

### Naming Convention

Sprite path pattern:
```
res://assets/sprites/{domain}/{entity}/{entity}_{state}.png
```

Example:
```
res://assets/sprites/enemies/basic_1/basic_1_idle.png
res://assets/sprites/enemies/basic_1/basic_1_move.png
res://assets/sprites/enemies/basic_1/basic_1_hit.png
res://assets/sprites/enemies/basic_1/basic_1_death.png
```

## Tools

### Sprite Generator

Python-based tool for generating 32x32 pixel spaceship sprites.

**Location**: [`spaceship-sprite-generator/`](spaceship-sprite-generator/)

**Requirements**:
- Python 3.x
- Pillow>=10.0.0

**Usage**:
```bash
cd spaceship-sprite-generator
pip install -r requirements.txt
python3 main.py
```

**Generated Output**:
```
sprites/
├── enemies/
│   ├── basic/    # 5 variants × 4 states = 20 sprites
│   ├── medium/  # 4 variants × 4 states = 16 sprites
│   └── heavy/   # 3 variants × 4 states = 12 sprites
└── bosses/
    └── 2 variants × 4 states = 8 sprites
```

**Customization**: Edit [`COLOR_SCHEMES`](spaceship-sprite-generator/sprite_generator.py:11) in `sprite_generator.py` to modify color palettes.

### Sprite Migration Script

Migrates enemy and boss `.tres` files from the old single-sprite schema to the new per-state sprite schema.

**Location**: [`migrate_sprites.py`](migrate_sprite.py)

**Usage**:
```bash
python3 migrate_sprites.py
```

This script:
1. Reads all `.tres` files in `data/enemies/` and `data/bosses/`
2. Maps entity IDs to sprite set folders
3. Adds new sprite path fields (`sprite_idle_path`, `sprite_move_path`, `sprite_hit_path`, `sprite_death_path`)
4. Removes old sprite fields

### Validation Tests

#### Spawn Distance Validation

Godot-based test that validates enemies never spawn too close to the player.

**Location**: [`polychrome-void/polychrome-void/tools/SpawnDistanceValidationTest.gd`](polychrome-void/polychrome-void/tools/SpawnDistanceValidationTest.gd)

**Run**: Execute from Godot editor or as a tool script

**Validates**:
- Minimum spawn distance: 170 pixels
- Tests spawn safety across arena positions
- Runs for 20 seconds with player moving in circular pattern

## Game Architecture

### Core Systems

- **SpawnDirector**: Manages enemy spawning with distance constraints
- **Player**: Player ship controller with movement and shooting
- **Enemy**: Base enemy class with multiple variants
- **Boss**: Boss enemy with phase transitions
- **Combat System**: Handles damage, health, and combat interactions

### Data-Driven Design

Game content is defined in Godot `.tres` (resource) files:

- **EnemyResource**: Enemy statistics, behavior, and visuals
- **BossResource**: Boss statistics, phases, and patterns
- **Pattern definitions**: Bullet pattern configurations

### Collision System

- Collision radii are **gameplay-authoritative** and independent of sprite dimensions
- Hitbox verification available via debug overlays

## Development

### Non-Negotiable Constraints

- **No allocations in hot loops** (performance critical)
- **Collision radii remain gameplay-authoritative**
- **Existing tuning and progression formulas unchanged** without approval
- **Preserve visual language**: Abstract, high-contrast, silhouette-first

### Migration Status

The project is currently undergoing a **sprite migration** from procedural geometry to 32x32 pixel sprites. See [`docs/14_SPRITE_MIGRATION_PLAN_32x32.md`](docs/14_SPRITE_MIGRATION_PLAN_32x32.md) for detailed migration phases and status.

### Phase Roadmap

1. ✅ **Phase 0**: Contract and Risk Control
2. 🔄 **Phase 1**: Asset Pipeline Definition
3. ⏳ **Phase 2**: Data Schema and Content Migration
4. ⏳ **Phase 3**: Rendering Integration
5. ⏳ **Phase 4**: Gameplay Parity Validation
6. ⏳ **Phase 5**: Performance and Platform Validation
7. ⏳ **Phase 6**: Rollout and Documentation

## License

This project is for educational/game development purposes.

## Contributing

When contributing to this project:

1. Maintain performance constraints (60 FPS on Pi 5)
2. Keep allocations out of hot loops
3. Preserve the abstract visual style
4. Update documentation when adding features
5. Test on both native and web targets
