## PatternResource — base class for enemy bullet-pattern definitions.
## Do not instantiate directly; use a concrete subclass .tres.
class_name PatternResource
extends Resource

## Unique key matching EnemyResource.pattern_id.
@export var id: StringName = &""

## Bullets fired per second.
@export var fire_rate: float = 1.5

## Speed of each spawned bullet in pixels/second.
@export var bullet_speed: float = 180.0
