## PatternResource — base class for enemy bullet-pattern definitions.
## Do not instantiate directly; use a concrete subclass .tres.
class_name PatternResource
extends Resource

## Unique key used for tooling/debug display.
@export var id: StringName = &""

## Bullets fired per second.
@export var fire_rate: float = 1.5

## Speed of each spawned bullet in pixels/second.
@export var bullet_speed: float = 180.0

## Tint applied to bullets emitted by this pattern.
@export var bullet_color: Color = Color(1.0, 0.3, 0.3, 1.0)
