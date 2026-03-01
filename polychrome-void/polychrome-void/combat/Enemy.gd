## Enemy — a single enemy unit.
## Loads an EnemyResource to define stats and pattern.
## Draws a solid square. CollisionSystem queries position + collision_radius.
## Instantiated by SpawnDirector; add via scenes/Enemy.tscn.
class_name Enemy
extends Node2D

## Unique per-run integer ID assigned by SpawnDirector.
var enemy_id: int = 0

## Collision radius read by CollisionSystem.
var collision_radius: float = 16.0

var _resource: EnemyResource = null
var _current_hp: float = 0.0
var _max_hp: float = 0.0
var _pattern_executor: Node = null
var _player_ref: Node2D = null

var _dead: bool = false

const HALF_SIZE: float = 14.0


## Initialise with a resource and scaled HP.  Call before adding to the scene tree.
func setup(res: EnemyResource, scaled_hp: float, id: int, player: Node2D) -> void:
	_resource = res
	_max_hp = scaled_hp
	_current_hp = scaled_hp
	enemy_id = id
	collision_radius = res.collision_radius
	_player_ref = player


func _ready() -> void:
	EventBus.bullet_hit_enemy.connect(_on_bullet_hit_enemy)


func _process(delta: float) -> void:
	if _dead or _player_ref == null:
		return
	# Simple seek behaviour — move toward player.
	var dir: Vector2 = (_player_ref.position - position).normalized()
	position += dir * _resource.speed * delta
	queue_redraw()


func _draw() -> void:
	if _dead:
		return
	var col: Color = _resource.color if _resource != null else Color.RED
	# Flash white at low HP.
	var hp_frac: float = _current_hp / _max_hp if _max_hp > 0.0 else 0.0
	if hp_frac < 0.25:
		col = col.lerp(Color.WHITE, 0.5)
	draw_rect(Rect2(-HALF_SIZE, -HALF_SIZE, HALF_SIZE * 2.0, HALF_SIZE * 2.0), col)
	draw_rect(Rect2(-HALF_SIZE, -HALF_SIZE, HALF_SIZE * 2.0, HALF_SIZE * 2.0),
		Color(1.0, 1.0, 1.0, 0.4), false, 1.0)

	# HP bar above enemy.
	var bar_w: float = HALF_SIZE * 2.0
	draw_rect(Rect2(-HALF_SIZE, -HALF_SIZE - 6.0, bar_w, 3.0), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-HALF_SIZE, -HALF_SIZE - 6.0, bar_w * hp_frac, 3.0), Color(0.2, 1.0, 0.2))


func _on_bullet_hit_enemy(id: int, damage: float) -> void:
	if id != enemy_id or _dead:
		return
	_current_hp -= damage
	if _current_hp <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	var score_val: int = _resource.score_value if _resource != null else 0
	EventBus.enemy_died.emit(enemy_id, position, score_val)
	queue_free()
