
# GitHub Copilot Custom Instructions for Polychrome Void

# Project Summary

You are assisting on **Polychrome Void**, an abstract geometric minimal bullet hell roguelite in **Godot 4.5** targeting **Raspberry Pi 5**. Follow the project’s architecture, naming conventions, and systems design rigorously.

# Core Rules

1. Always follow the project’s coding standards and architecture laid out in the project docs.
2. Use typed GDScript conforming to Godot 4.5 patterns.
3. Prioritize performance-aware solutions (e.g., pooled bullets, no per-bullet nodes).
4. Write modular systems that follow the Game Design Doc and Technical Design Doc.
5. Favor clear, minimal code that matches the game’s abstract visual style.
6. Provide explanatory comments where design decisions are non-trivial.

# When generating code, prioritize the following:

- deterministic math for patterns
- minimal allocations in update loops
- explicit typing, avoid untyped dynamic data
- use MultiMeshInstance2D for batched rendering
