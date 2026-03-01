## RadialBurstPatternResource — fires a ring of bullets then pauses.
class_name RadialBurstPatternResource
extends PatternResource

## Number of bullets evenly distributed in a full circle per burst.
@export var bullet_count: int = 12

## Seconds to wait between bursts (overrides fire_rate for burst timing).
@export var burst_interval: float = 1.2
