## BossPhaseResource — configuration for a single boss phase.
class_name BossPhaseResource
extends Resource

## HP fraction at which this phase begins (0.0–1.0, checked from highest).
## Phase 0 is active from full HP until hp_threshold is crossed.
@export var hp_threshold: float = 0.66

## Pattern to use during this phase (must be a PatternResource subclass).
@export var pattern: PatternResource = null

## Speed multiplier applied to the boss during this phase.
@export var speed_multiplier: float = 1.0

## Color shift for the boss polygon during this phase.
@export var phase_color: Color = Color(1.0, 0.5, 0.0, 1.0)
