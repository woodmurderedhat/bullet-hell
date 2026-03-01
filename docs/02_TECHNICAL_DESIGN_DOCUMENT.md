# Technical Design Document (TDD)

## Engine
Godot 4.5 (2D only)

## Folder Structure
res://
  core/
  systems/
  combat/
  player/
  ui/
  audio/
  data/
  scenes/
  tools/

## Core Systems
- BulletManager (pooled, MultiMesh)
- CollisionSystem (manual checks)
- SpawnDirector (dynamic pacing)
- ModifierComponent (data-driven)
- EventBus (decoupled messaging)