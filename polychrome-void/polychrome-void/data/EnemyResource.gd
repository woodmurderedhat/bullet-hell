## EnemyResource — data definition for a single enemy archetype.
## Create .tres instances in res://data/enemies/ for each enemy type.
class_name EnemyResource
extends Resource

## Unique string key used to identify this enemy type.
@export var id: StringName = &""

## Base hit-points before arena-index scaling.
## Scaled at runtime: base_hp * (1 + arena_index * 0.12)
@export var base_hp: float = 40.0

## Movement speed in pixels per second.
@export var speed: float = 80.0

## Radius used for manual collision checks (pixels).
@export var collision_radius: float = 16.0

## The pattern resource id this enemy fires.
## Must match a PatternResource.id loaded by BulletManager/PatternExecutor.
@export var pattern_id: StringName = &""

## Visual tint for the enemy square (informational colour coding).
@export var color: Color = Color(0.9, 0.2, 0.2, 1.0)

## Score reward when killed.
@export var score_value: int = 10
