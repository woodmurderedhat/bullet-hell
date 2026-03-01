---
## 🧩 4. `godot-patterns/SKILL.md`

Teaches Copilot about bullet patterns and how to produce pattern logic consistent with the design doc.

```md
---
name: godot-patterns
description: "Instructions for generating bullet pattern code snippets for Godot 4.5 based on project requirements."
license: "MIT"
--------------

When asked to generate or modify bullet pattern code:

1. Use deterministic math (e.g., sin/cos) instead of timers where possible.
2. Use vector math and avoid physics engine calls for bullet movement.
3. Patterns should call into the `BulletManager.spawn_bullet()` API.
4. Example format for a pattern update function:

```gdscript
func update_pattern(delta: float, emitter_position: Vector2):
    angle += angular_speed * delta
    var vel = Vector2.RIGHT.rotated(angle) * speed
    BulletManager.spawn_bullet(position = emitter_position, velocity = vel, damage = base_damage)
```
