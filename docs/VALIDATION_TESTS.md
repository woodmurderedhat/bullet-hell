# Validation Tests Documentation

## Overview

Polychrome Void includes automated validation tests to ensure gameplay integrity, particularly around spawn safety and collision systems. These tests run within the Godot editor or as standalone tool scripts.

## Spawn Distance Validation Test

### Purpose

Ensures enemies never spawn too close to the player, maintaining fair gameplay and preventing cheap deaths. The test validates the `min_spawn_distance_to_player` constraint across all spawn scenarios.

**Location**: [`polychrome-void/polychrome-void/tools/SpawnDistanceValidationTest.gd`](polychrome-void/polychrome-void/tools/SpawnDistanceValidationTest.gd)

### Test Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `TEST_SECONDS` | 20.0 | Duration of test in seconds |
| `min_safe_distance` | 170.0 | Minimum allowed spawn distance in pixels |
| Resolution | 1280x720 | Standard game resolution |

### Test Methodology

1. **Instantiates Main Scene**: Creates a game instance
2. **Player Movement**: Moves player in a circular pattern to test spawn safety across arena positions
3. **Enemy Validation**: Checks each active enemy spawn against the minimum distance constraint
4. **Boss Validation**: Validates boss spawn distances separately
5. **Violation Tracking**: Records any spawns below minimum distance threshold

### Player Movement Pattern

The test moves the player in a figure-8 inspired pattern:
```gdscript
player.position = Vector2(640.0 + cos(t) * 180.0, 360.0 + sin(t * 1.4) * 130.0)
```

This covers:
- Center of arena
- Edges and corners
- Various movement states

### Running the Test

#### From Godot Editor

1. Open Godot project
2. Navigate to `tools/SpawnDistanceValidationTest.gd`
3. Run the script or press F5 (if configured as main)

#### As Tool Script

The test extends `Node` and can be run as an automated tool.

### Output Interpretation

#### Success Output

```
[SpawnDistanceValidationTest] Running...
[SpawnDistanceValidationTest] PASS  ~150 spawns validated, no violations below 170 px
```

#### Failure Output

```
[SpawnDistanceValidationTest] Running...
[SpawnDistanceValidationTest] FAIL  3 violations out of ~150 spawns:
  - enemy (id=5): distance=145.2 px (min=170.0 px)
  - enemy (id=12): distance=160.5 px (min=170.0 px)
  - boss (id=1): distance=155.0 px (min=170.0 px)
```

### Troubleshooting Failed Tests

If the test fails:

1. **Check SpawnDirector Logic**: Verify spawn point calculation includes minimum distance check
2. **Review Arena Bounds**: Ensure spawn points account for player position within arena
3. **Verify Timing**: Check that enemies aren't spawning before player position updates

## Test Infrastructure

### Required Scene References

The test requires these nodes to exist in the main scene:

| Node | Type | Purpose |
|------|------|---------|
| `Player` | Player | Player ship instance |
| `SpawnDirector` | SpawnDirector | Enemy spawning system |

### Node Group Requirements

- Enemies must be in the `"enemies"` group for detection

### Test Setup Code

```gdscript
const MAIN_SCENE := preload("res://scenes/Main.tscn")
const TEST_SECONDS: float = 20.0
```

### Distance Calculation

```gdscript
var distance: float = enemy.global_position.distance_to(player.global_position)
if distance < min_safe_distance:
    violations.append({...})
```

## Integration with CI/CD

This test can be integrated into automated build pipelines:

1. Run Godot headless with the test scene
2. Parse console output for PASS/FAIL
3. Fail build on test failure

## Related Tests

Future test additions may include:
- Collision parity tests
- Performance stress tests
- Bullet pattern accuracy tests
- UI element positioning tests

## Related Documentation

- [Main README](../README.md) - Project overview
- [Sprite Migration Plan](14_SPRITE_MIGRATION_PLAN_32x32.md) - Migration phases
