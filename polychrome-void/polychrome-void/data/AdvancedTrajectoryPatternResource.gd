## AdvancedTrajectoryPatternResource - configurable special trajectories.
class_name AdvancedTrajectoryPatternResource
extends PatternResource

enum TrajectoryMode {
	SINE,
	CURVED,
	SPLIT,
	HOMING,
}

@export var mode: TrajectoryMode = TrajectoryMode.SINE
@export var bullet_count: int = 1
@export var burst_interval: float = 0.65
@export var spread_degrees: float = 0.0
@export var track_target: bool = true
@export var base_angle_offset: float = 0.0

# Sine mode.
@export var sine_amplitude: float = 36.0
@export var sine_frequency: float = 8.0
@export var sine_phase_step: float = 0.4

# Curved and homing mode.
@export var turn_rate: float = 2.4
@export var homing_delay: float = 0.45

# Splitting mode.
@export var split_time: float = 0.55
@export var split_count: int = 3
@export var split_spread_degrees: float = 70.0
@export var split_speed_scale: float = 0.9
@export var split_depth: int = 1
