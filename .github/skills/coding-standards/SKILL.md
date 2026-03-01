---
name: coding-standards
description: "Detailed coding standards for Polychrome Void, instructing how Copilot should write code that fits the project’s style."
license: "MIT"
---
When generating code for this project:

1. Always use typed GDScript (e.g., `var count: int = 0`).
2. No deep inheritance; use composition via components.
3. Place new systems in their correct folder (`combat/`, `core/`, `player/`, `systems/`).
4. In GDScript, preload resources at the top of scripts:

```gdscript
const SOME_TEXTURE = preload("res://resources/some_texture.tres")
```
5. Write clear docstrings for classes and functions tied to gameplay mechanics.

6. In hot loops (_process, pattern updates), avoid dynamic allocations.
