## PlayerVisualConfig - sprite metadata contract for the player actor.
## Keeps visual data decoupled from gameplay stat tuning.
class_name PlayerVisualConfig
extends Resource

## Optional sprite sheet path for 32x32 visual migration.
@export_file("*.png") var sprite_texture_path: String = ""

## Region origin in pixels inside a sprite atlas.
@export var sprite_region_origin: Vector2i = Vector2i.ZERO

## Number of 32x32 frames used by the primary animation strip.
@export_range(1, 32, 1) var sprite_frame_count: int = 1

## Animation playback rate for the primary strip.
@export_range(0.0, 30.0, 0.1) var sprite_fps: float = 8.0
