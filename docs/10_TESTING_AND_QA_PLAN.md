# Testing & QA

Unit Tests:
- Stat math
- RNG determinism

Integration Tests:
- Spawn waves under performance limits

Performance Tests:
- Stress test 4000 bullets

Long-Session Balance Runs (45-60 min target):
- Run deterministic seed matrix (minimum 5 seeds) for DPS-heavy, sustain-heavy, and hybrid upgrade archetypes.
- Track per-run KPIs: levels cleared, time survived, boss kills, player damage taken per minute, and average enemy TTK.
- Validate early-run pacing guardrail: Arena 1 should remain survivable for non-perfect play with mixed upgrades.
- Validate mid/late pressure guardrail: Arena 2+ should show visible attrition without one-shot dominance on baseline loadouts.
- Verify upgrade offer health under new weights: no pool starvation, branch locks still produce coherent build paths.
- Re-run stat math checks after balancing edits to confirm additive/multiplicative calculations remain stable.
- Re-run performance stress pass with high split/chain builds after spawn pressure changes.