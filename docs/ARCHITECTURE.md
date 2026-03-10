# Game Architecture Documentation

## Overview

Polychrome Void is a data-driven bullet hell game built on the Godot 4.x engine. The architecture emphasizes performance, maintainability, and clear separation of concerns.

## Core Architecture Principles

### Performance First

- **No allocations in hot loops**: Object pooling for bullets and effects
- **MultiMesh rendering**: Bullets rendered via GPU instancing
- **Fixed timestep**: Physics and game logic run at consistent intervals

### Data-Driven Design

- **Resource-based content**: Enemies, bosses, and patterns defined in `.tres` files
- **Separation of concerns**: Data defines "what", code defines "how"

### Collision Authoritative

- Collision radii are gameplay values, not derived from sprites
- Hitbox debug overlays available for verification

## Directory Structure

```
polychrome-void/polychrome-void/
├── assets/          # Visual assets (sprites, textures)
├── audio/           # Sound effects and music
├── combat/          # Combat mechanics
├── core/            # Core game systems
├── data/            # Game data resources
├── player/          # Player ship
├── scenes/          # Godot scenes
├── systems/         # Game systems
├── tools/           # Editor tools and tests
└── ui/             # User interface
```

### Asset System (`assets/`)

Contains all visual resources organized by domain:

```
assets/
└── sprites/
    ├── bosses/     # Boss sprite sheets
    │   └── boss_1/
    │       ├── boss_1_idle.png
    │       ├── boss_1_move.png
    │       ├── boss_1_hit.png
    │       └── boss_1_death.png
    └── enemies/    # Enemy sprite sheets
        ├── basic_1/
        ├── medium_1/
        └── heavy_1/
```

### Data System (`data/`)

Contains Godot resource files (`.tres`) defining game content:

```
data/
├── bosses/        # Boss definitions (.tres)
├── enemies/       # Enemy definitions (.tres)
├── expansions/   # Expansion content
├── patterns/     # Bullet patterns
└── upgrades/     # Player upgrades
```

### Resource Schema

#### EnemyResource

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique identifier |
| `enemy_id` | int | Numeric ID |
| `sprite_idle_path` | String | Idle sprite path |
| `sprite_move_path` | String | Movement sprite path |
| `sprite_hit_path` | String | Hit state sprite path |
| `sprite_death_path` | String | Death animation sprite path |
| `hit_state_duration` | float | Hit flash duration (seconds) |
| `death_state_duration` | float | Death animation duration |
| `collision_radius` | float | Hitbox radius (gameplay value) |
| `max_hp` | float | Maximum health |
| `score_value` | int | Points awarded on defeat |
| `movement_pattern` | String | Movement behavior type |
| `fire_rate` | float | Shots per second |
| `damage` | float | Damage per hit |

#### BossResource

| Field | Type | Description |
|-------|------|-------------|
| `id` | String | Unique identifier |
| `boss_id` | int | Numeric ID |
| `sprite_*_path` | String | Per-state sprite paths |
| `phases` | Array | Phase definitions |
| `collision_radius` | float | Hitbox radius |
| `max_hp` | float | Total health across phases |

## Core Systems

### Player System (`player/`)

The player ship is the controlled entity in the game:

- **Movement**: 8-directional movement with acceleration/deceleration
- **Shooting**: Primary weapon with configurable fire rate
- **Health**: HP and shield system
- **Upgrades**: Modular upgrade system

### Enemy System (`combat/` or root)

Base enemy class with multiple specialized variants:

- **Basic Enemies**: Simple movement patterns, low HP
- **Medium Enemies**: Complex patterns, medium HP
- **Heavy Enemies**: Tanky, multiple attack types
- **Bosses**: Multi-phase encounters with pattern variations

### Spawn System

Managed by `SpawnDirector`:

- **Spawn Pooling**: Reuses inactive enemy instances
- **Distance Constraints**: Minimum spawn distance from player (170px)
- **Wave Management**: Controls spawn timing and composition

### Combat System

Handles all combat interactions:

- **Collision Detection**: Entity-to-entity and entity-to-bullet
- **Damage Application**: HP reduction with invulnerability frames
- **Effect Triggers**: Spawns effects on hit/death

### Bullet System

Optimized for high object counts:

- **MultiMesh Rendering**: GPU-instanced drawing
- **Object Pooling**: Reuses bullet instances
- **Pattern Injection**: Configurable flight paths

## Rendering Pipeline

### Sprite Rendering

1. **Animation Controller**: Manages sprite state transitions
2. **Sprite2D Node**: Renders current state texture
3. **Transform**: Position and rotation from gameplay

### Bullet Rendering

1. **MultiMeshInstance2D**: Single draw call for all bullets
2. **Instance Transforms**: Per-bullet position/rotation
3. **Color/UV**: Per-bullet customization

## Performance Targets

| Metric | Target | Validation |
|--------|--------|------------|
| Frame Rate | 60 FPS | Automated stress test |
| Max Enemies | 150 | Spawn test |
| Max Bullets | 4000 | MultiMesh capacity |
| Max Effects | 300 | Particle budget |
| Memory | <512MB | Platform test |

## Platform Support

### Raspberry Pi 5 (Native)

- **Resolution**: 1280x720
- **Renderer**: Compatibility mode (OpenGL ES 3.0)
- **Target FPS**: 60

### Web (HTML5)

- **Renderer**: WebGL 2.0
- **Export**: Godot HTML5 export
- **Performance**: Same as native within browser constraints

## Testing Infrastructure

### Automated Tests

- **Spawn Distance Validation**: Ensures spawn safety
- **Collision Parity**: Verifies hitbox behavior
- **Performance Profiling**: Frame time monitoring

### Debug Features

- **Hitbox Overlays**: Visual collision debugging
- **FPS Counter**: Performance monitoring
- **Entity Counters**: Object pooling statistics

## Related Documentation

- [Sprite Generator](SPRITE_GENERATOR.md) - Sprite creation tools
- [Migration Script](MIGRATION_SCRIPT.md) - Data migration
- [Validation Tests](VALIDATION_TESTS.md) - Testing infrastructure
- [Sprite Migration Plan](14_SPRITE_MIGRATION_PLAN_32x32.md) - Migration details
- [Main README](../README.md) - Project overview
