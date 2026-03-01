## BossResource — data definition for a multi-phase boss encounter.
## Create .tres instances in res://data/bosses/
class_name BossResource
extends Resource

## Unique string key for this boss.
@export var id: StringName = &""

## Base HP before arena scaling.
@export var base_hp: float = 600.0

## Movement speed in pixels/second (base; each phase may scale this).
@export var speed: float = 60.0

## Collision radius used by CollisionSystem.
@export var collision_radius: float = 40.0

## Visual tint for the boss polygon at full health.
@export var base_color: Color = Color(1.0, 1.0, 0.2, 1.0)

## Score reward when fully defeated.
@export var score_value: int = 500

## Phase definitions ordered from first to last.
## Phases are evaluated in order; when current_hp / max_hp drops below
## phases[i].hp_threshold, the boss transitions to phases[i+1].
@export var phases: Array[BossPhaseResource] = []
