## EnemyResource — data definition for a single enemy archetype.
## Create .tres instances in res://data/enemies/ for each enemy type.
class_name EnemyResource
extends Resource

enum MovementType {
	CHASER,
	STRAFING,
	ORBITING,
	DASHING,
	WAVY,
}

## Unique string key used to identify this enemy type.
@export var id: StringName = &""

## Base hit-points before arena-index scaling.
## Scaled at runtime: base_hp * (1 + arena_index * 0.12)
@export var base_hp: float = 40.0

## Movement speed in pixels per second.
@export var speed: float = 80.0

## Radius used for manual collision checks (pixels).
@export var collision_radius: float = 16.0

## Pattern this enemy uses for firing.
@export var pattern: PatternResource = null

## Movement behaviour profile.
@export var movement_type: MovementType = MovementType.CHASER

## How strongly strafe/orbit mixes lateral movement [0..1].
@export_range(0.0, 1.0, 0.01) var lateral_weight: float = 0.65

## Preferred radius around player for ORBITING behaviour.
@export var preferred_range: float = 180.0

## Seconds between DASHING bursts.
@export var dash_interval: float = 1.8

## Duration in seconds for one DASHING burst.
@export var dash_duration: float = 0.28

## Speed multiplier while dashing.
@export var dash_speed_multiplier: float = 2.2

## Wavy phase speed in radians per second.
@export var wave_frequency: float = 2.2

## Wavy lateral velocity contribution in px/s.
@export var wave_amplitude: float = 85.0

## Visual tint for the enemy square (informational colour coding).
@export var color: Color = Color(0.9, 0.2, 0.2, 1.0)

## Score reward when killed.
@export var score_value: int = 10
