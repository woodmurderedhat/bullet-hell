# 32x32 Sprite Migration Plan

## Goal

Migrate Player, Enemy, and Boss visuals from procedural geometry to 32x32 pixel sprites while preserving gameplay behavior, collision semantics, and target performance on Raspberry Pi 5.

Out of scope for this migration:
- Bullet rendering architecture changes (bullets remain pooled MultiMesh).

## Non-Negotiable Constraints

- Target platform and performance remain unchanged: 1280x720 at 60 FPS on Raspberry Pi 5.
- No allocations in hot loops.
- Collision radii remain gameplay-authoritative and must not be inferred from sprite dimensions.
- Existing tuning and progression formulas remain unchanged unless explicitly approved.
- Preserve the project visual language: abstract, high-contrast, silhouette-first.

## Phase 0: Contract and Risk Control

1. Lock migration scope.
- Included: Player, Enemy, Boss sprite visuals.
- Excluded: bullets, collision architecture, progression formulas.

2. Add style exception to art docs.
- Core actors may use 32x32 sprites.
- Keep gradients disabled and readability high.

3. Establish rollback strategy.
- Use temporary render mode toggles so procedural `_draw()` can be restored quickly during parity testing.

Exit criteria:
- Team agrees on scope, risk, and rollback approach.

## Phase 1: Asset Pipeline Definition

1. Define sprite bible.
- Canvas: 32x32.
- Pivot: center for all actors.
- Facing policy: actor rotation still driven by gameplay vectors.
- Required states:
  - Player: `idle`, `move`, `hit`, `death`.
  - Enemy: `idle`, `move`, `hit`, `death`.
  - Boss: `idle`, `move`, `hit`, `phase_transition`, `death`.

2. Define naming/version policy.
- Recommended path pattern:
  - `res://assets/sprites/{domain}/{entity}/{entity}_{state}_vNN.png`

3. Define import policy for pixel assets.
- Nearest-neighbor filtering.
- No mipmaps.
- Consistent compression policy across native and web targets.

4. Define art QA gates.
- Silhouette clarity at gameplay scale.
- Contrast compliance against black background.
- Complete state coverage before integration.

Exit criteria:
- Sprite pipeline and review rubric published.

## Phase 2: Data Schema and Content Migration

1. Extend resource schemas with visual metadata.
- EnemyResource fields:
  - `sprite_texture_path`
  - `sprite_region_origin`
  - `sprite_frame_count`
  - `sprite_fps`
- BossResource fields:
  - `sprite_texture_path`
  - `sprite_region_origin`
  - `sprite_frame_count`
  - `sprite_fps`

2. Add equivalent player visual config.
- Resource file or typed constants, but same metadata contract.

3. Migrate content assets.
- Update all `data/enemies/*.tres` and `data/bosses/*.tres` with valid visual metadata.

4. Add validation.
- Startup/content check for missing textures or invalid frame metadata.

Exit criteria:
- All core actor content resolves valid visual metadata.

## Phase 3: Rendering Integration

1. Scene composition updates.
- Add `Sprite2D` (or equivalent composed visual node) in actor scenes.

2. Animation controller.
- Implement lightweight, typed state controller with deterministic transitions.
- Avoid per-frame dynamic allocations.

3. Render mode transition.
- Keep temporary fallback path so geometry can be re-enabled for parity checks.

4. Overlay alignment.
- Re-anchor HP bars and shield offsets based on sprite pivots.

Exit criteria:
- Player, Enemy, and Boss render from sprite paths with animation state changes.

## Phase 4: Gameplay Parity Validation

1. Collision parity.
- Verify no collision regressions despite visual changes.

2. Orientation parity.
- Player aim direction matches sprite orientation.
- Enemy movement vectors match visual facing.
- Boss phase transitions drive intended visual state changes.

3. Tuning parity.
- Confirm no unintended changes to movement speed, fire rate, bullet speed, damage, or scaling formulas.

Exit criteria:
- Gameplay behavior matches baseline within expected tolerances.

## Phase 5: Performance and Platform Validation

1. Raspberry Pi 5 stress profile.
- Scenarios include caps from performance spec:
  - 150 enemies
  - 4000 bullets
  - 300 effects
- Confirm FPS and frame-time stability.

2. Rendering cost audit.
- Confirm bullet path remains MultiMesh.
- Measure draw-call and memory deltas from actor sprites.

3. Web export validation.
- Verify sprite imports, layering, and acceptable runtime performance in browser.

Exit criteria:
- Native and web targets pass performance and visual checks.

## Phase 6: Rollout and Documentation

1. Remove temporary fallback toggles after sign-off.
2. Keep debug overlays for hitbox/pivot verification.
3. Update test plan and release checklist with sprite-specific gates.
4. Archive before/after captures for regression reference.

Exit criteria:
- Migration is stable, documented, and release-ready.

## Test Matrix

- Rendering:
  - Player/enemy/boss sprites load and animate by state.
  - HP bars and overlays remain legible and correctly layered.
- Collision:
  - Player, enemy, and boss hit behavior unchanged.
  - Shield interactions unchanged.
- Combat parity:
  - No drift in damage, fire cadence, or movement behavior.
- Performance:
  - RP5 stays at target FPS under stress.
  - No frame-time spikes from sprite animation updates.
- Platform compatibility:
  - Native export and HTML5 export both pass smoke tests.

## Work Breakdown Priority

1. Data schema + content validation.
2. Player sprite integration.
3. Enemy sprite integration.
4. Boss sprite integration.
5. Performance pass and regression pass.

## Immediate Next Tasks

1. Create player visual config contract (resource or constants).
2. Add render-mode feature toggle to player/enemy/boss scripts.
3. Add startup validation for sprite metadata references.
4. Begin `.tres` migration for one enemy archetype and one boss as pilot samples.
