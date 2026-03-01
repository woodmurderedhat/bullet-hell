## EventBus — global decoupled messaging hub.
## All inter-system communication goes through signals defined here.
## Autoloaded as "EventBus".
extends Node

# ---------------------------------------------------------------------------
# Player signals
# ---------------------------------------------------------------------------

## Emitted when the player takes a hit from an enemy bullet.
signal bullet_hit_player(damage: float)

## Emitted when the player's HP reaches zero.
signal player_died()

## Emitted whenever the player fires a shot burst.
signal player_fired()

# ---------------------------------------------------------------------------
# Enemy signals
# ---------------------------------------------------------------------------

## Emitted by CollisionSystem when a player bullet hits an enemy.
## enemy_id matches the id assigned by SpawnDirector.
signal bullet_hit_enemy(enemy_id: int, damage: float)

## Emitted when an enemy's HP reaches zero.
signal enemy_died(enemy_id: int, position: Vector2, score: int)

# ---------------------------------------------------------------------------
# Boss signals
# ---------------------------------------------------------------------------

## Emitted when the boss transitions to a new attack phase.
signal boss_phase_changed(phase_index: int)

# ---------------------------------------------------------------------------
# Wave / arena signals
# ---------------------------------------------------------------------------

## Emitted by SpawnDirector when all enemies in the current wave are dead.
signal wave_complete(arena_index: int)

## Emitted by SpawnDirector when a boss encounter wave begins.
signal boss_wave_started(arena_index: int)

# ---------------------------------------------------------------------------
# Upgrade signals
# ---------------------------------------------------------------------------

## Emitted by UpgradePicker when the player selects an upgrade card.
signal upgrade_chosen(resource: Resource)

# ---------------------------------------------------------------------------
# Run lifecycle signals
# ---------------------------------------------------------------------------

## Emitted at the end of a run (win or lose).
## result is a Dictionary with keys: "won" (bool), "score" (int), "arena_reached" (int).
signal run_ended(result: Dictionary)

## Emitted when a meta reward is granted (currency or unlock).
signal meta_reward_earned(currency_delta: int, unlock_id: StringName)

# ---------------------------------------------------------------------------
# Score signal
# ---------------------------------------------------------------------------

## Emitted when the score changes.
signal score_changed(new_score: int)
