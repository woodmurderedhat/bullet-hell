## RingPatternResource - expanding or collapsing ring emission.
class_name RingPatternResource
extends PatternResource

enum RingMode {
	EXPANDING,
	COLLAPSING,
}

@export var bullet_count: int = 16
@export var ring_interval: float = 0.9
@export var spawn_radius: float = 0.0
@export var ring_mode: RingMode = RingMode.EXPANDING
