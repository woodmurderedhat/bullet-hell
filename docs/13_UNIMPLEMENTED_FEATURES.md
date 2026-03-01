# Polychrome Void — Unimplemented Features Gap Analysis

> **Document Purpose:** This document catalogs all features referenced in the game's design documentation that have not yet been implemented in the codebase. It serves as a roadmap for prioritizing future development efforts and identifying core gameplay gaps.

---

## Table of Contents

1. [Audio System](#audio-system)
2. [UI/Menu Systems](#uimenus-systems)
3. [Performance Telemetry](#performance-telemetry)
4. [Boss Content](#boss-content)
5. [Enemy Content](#enemy-content)
6. [Testing/QA Tools](#testingqa-tools)
7. [Save System](#save-system)
8. [Meta Progression](#meta-progression)
9. [Platform Integration](#platform-integration)

---

## 1. Audio System

| Priority | Feature | Description |
|----------|---------|-------------|
| **HIGH** | Audio asset files | The [`AudioManager.gd`](polychrome-void/audio/AudioManager.gd) script exists but contains no `.wav` or `.ogg` audio files loaded into its configuration. |
| **HIGH** | Minimal synth music tracks | Background music tracks for gameplay loops are not present. |
| **HIGH** | Glitch accent SFX | Sound effects for visual glitch effects and accent moments are missing. |
| **HIGH** | Layered boss music | Boss encounters lack dedicated layered music tracks that intensify during phases. |
| **HIGH** | Placeholder SFX hooks | All sound effect hooks in the code are empty placeholders: `shoot`, `hit`, `enemy_die`, `boss_phase`, and `upgrade`. |

**Impact:** The game currently plays in complete silence, significantly diminishing the intended atmospheric experience described in the [Audio Direction Document](docs/05_AUDIO_DIRECTION_DOCUMENT.md).

---

## 2. UI/Menu Systems

| Priority | Feature | Description |
|----------|---------|-------------|
| **HIGH** | Pause Menu | No pause functionality exists. Pressing ESC or any pause hotkey does nothing. The game cannot be paused during gameplay. |
| **HIGH** | Settings/Options Menu | No configuration screen exists for adjusting controls, audio volume, or graphics settings. |
| **HIGH** | Controls Configuration Screen | No interface for remapping keyboard/input keys. Players cannot customize their control scheme. |
| **HIGH** | Victory/Run Complete Screen | Only the "YOU DIED" game over screen is implemented. There is no win state or completion screen when the player successfully finishes a run. |
| **HIGH** | High Score Leaderboard | No leaderboard system or persistent high scores display exists. |
| **HIGH** | Tutorial/How-to-Play Screen | No tutorial or controls explanation screen. New players have no in-game guidance. |

**Impact:** These are critical player experience gaps. The absence of a pause menu and settings menu is particularly problematic for a polished game release.

---

## 3. Performance Telemetry

| Priority | Feature | Description |
|----------|---------|-------------|
| **HIGH** | Performance telemetry system | Referenced in the [Release Checklist](docs/12_RELEASE_CHECKLIST.md) but never implemented. |
| **HIGH** | Runtime FPS monitoring UI | No in-game FPS counter or performance overlay for players. |
| **HIGH** | Play session statistics | No tracking or display of session duration, enemies killed, damage dealt, etc. |

**Impact:** Without telemetry, diagnosing player performance issues and understanding player behavior is impossible.

---

## 4. Boss Content

| Priority | Feature | Description |
|----------|---------|-------------|
| **MEDIUM** | Additional boss definitions | Only 1 boss is defined ([`boss_01.tres`](polychrome-void/data/bosses/boss_01.tres)). No other boss entries exist in `data/bosses/`. |
| **MEDIUM** | Expanded attack patterns | Only radial burst and spiral bullet patterns are used. Other pattern types referenced in [`PatternExecutor.gd`](polychrome-void/combat/PatternExecutor.gd) may not be fully utilized. |

**Impact:** The boss encounters lack variety. A single boss provides insufficient challenge and content for a full game.

---

## 5. Enemy Content

| Priority | Feature | Description |
|----------|---------|-------------|
| **MEDIUM** | Additional enemy types | Only 9 enemy types exist in `data/enemies/`. The original GDD envisioned a broader variety of enemy archetypes. |
| **MEDIUM** | Expanded movement patterns | Only 5 movement behaviors are implemented: `CHASER`, `STRAFING`, `ORBITING`, `DASHING`, and `WAVY`. Additional patterns may be needed for richer combat encounters. |

**Impact:** Enemy variety limits replayability and reduces the depth of the wave-based progression system.

---

## 6. Testing/QA Tools

| Priority | Feature | Description |
|----------|---------|-------------|
| **MEDIUM** | Integration tests for spawn waves | No automated tests for spawn wave behavior under heavy load. |
| **MEDIUM** | Automated playtests | No automated gameplay simulation for regression testing. |
| **MEDIUM** | Visual regression tests | No screenshot comparison tests for catching visual regressions. |
| **MEDIUM** | Save system verification tests | No automated tests for save/load integrity. |

**Impact:** Manual testing is the only verification method, increasing the risk of regressions and bugs in shipped builds.

---

## 7. Save System

| Priority | Feature | Description |
|----------|---------|-------------|
| **LOW** | Multiple save slots | Only a single save file is supported. Players cannot maintain multiple playthroughs. |
| **LOW** | Cloud save functionality | No cloud-based save storage for cross-device progress. |

**Impact:** Low priority for initial release, but valuable for player retention in post-launch support.

---

## 8. Meta Progression

| Priority | Feature | Description |
|----------|---------|-------------|
| **LOW** | New Game+ / Endless mode | No post-game mode with increased difficulty or endless waves. |
| **LOW** | Character/loadout selection | No ability to choose different ship archetypes or starting loadouts. |
| **LOW** | Daily challenges/modifiers | No time-limited challenges or rotating game modifiers. |

**Impact:** These features enhance long-term engagement but are not required for an initial feature-complete release.

---

## 9. Platform Integration

| Priority | Feature | Description |
|----------|---------|-------------|
| **LOW** | Steam achievements | No Steam API integration for achievement tracking. |
| **LOW** | Platform leaderboards | No integration with platform-specific leaderboard systems. |

**Impact:** Platform integration is valuable for Steam release but not blocking for initial development.

---

## Implementation Update (2026-03-02)

This section records the current implementation pass status. The original gap tables above are preserved as historical baseline.

### Status Key

- **IMPLEMENTED**: Feature is now present and wired in the game.
- **PARTIAL**: Feature has a local/fallback implementation, but native platform SDK integration is still pending.
- **PENDING**: Not yet implemented.

### High Priority

| Feature Area | Status | Notes |
|--------------|--------|-------|
| Audio asset hooks and playback | **IMPLEMENTED** | Procedural SFX/music added, including `shoot`, `hit`, `enemy_die`, `boss_phase`, and `upgrade`. |
| Minimal synth music | **IMPLEMENTED** | Procedural gameplay loop added via `AudioManager`. |
| Glitch accent SFX | **IMPLEMENTED** | Glitch SFX event added on boss phase transitions. |
| Layered boss music | **IMPLEMENTED** | Boss intensity layer starts on boss wave and stops after boss arena ends. |
| Pause menu | **IMPLEMENTED** | ESC pause flow added with resume/quit controls. |
| Settings/options menu | **IMPLEMENTED** | Audio volume, telemetry overlay toggle, cloud mirror toggle. |
| Controls configuration | **IMPLEMENTED** | Key remapping UI for core actions with save persistence. |
| Victory/run complete screen | **IMPLEMENTED** | Distinct run complete/fail screen with stats and replay/menu actions. |
| High score leaderboard | **IMPLEMENTED** | Persistent top scores shown in meta menu. |
| Tutorial/how-to-play | **IMPLEMENTED** | Tutorial panel available from menu and in-run pause UI. |
| Performance telemetry system | **IMPLEMENTED** | `TelemetryService` added with runtime metrics. |
| Runtime FPS monitoring UI | **IMPLEMENTED** | HUD overlay includes current/avg/min FPS. |
| Session statistics | **IMPLEMENTED** | Time, kills, damage dealt/taken, upgrades tracked/displayed. |

### Medium Priority

| Feature Area | Status | Notes |
|--------------|--------|-------|
| Additional boss definitions | **IMPLEMENTED** | Added `boss_02.tres` and `boss_03.tres`; boss rotation added to spawn flow. |
| Expanded attack patterns | **IMPLEMENTED** | Added arc and cross patterns and executor support. |
| Additional enemy types | **IMPLEMENTED** | Added new enemy resources and integrated into spawn roster. |
| Expanded movement patterns | **IMPLEMENTED** | Added `KITING`, `ZIGZAG`, and `SENTRY`. |
| Spawn wave integration tests | **IMPLEMENTED** | Tool scene/script added. |
| Automated playtests | **IMPLEMENTED** | Tool scene/script added. |
| Visual regression tests | **IMPLEMENTED** | Hash-based capture/compare tool scene/script added. |
| Save verification tests | **IMPLEMENTED** | Save slot isolation test scene/script added. |

### Low Priority

| Feature Area | Status | Notes |
|--------------|--------|-------|
| Multiple save slots | **IMPLEMENTED** | 3-slot save support added. |
| Cloud save functionality | **PARTIAL** | Local cloud-mirror fallback implemented; external cloud provider integration pending. |
| New Game+ / Endless mode | **IMPLEMENTED** | Endless mode toggle added in meta menu. |
| Character/loadout selection | **IMPLEMENTED** | Loadout cycling added (Balanced/Striker/Tank baselines). |
| Daily challenges/modifiers | **IMPLEMENTED** | Daily deterministic stat modifier seeded by date. |
| Steam achievements | **PARTIAL** | Local platform abstraction + achievement persistence implemented; Steam SDK bridge pending. |
| Platform leaderboards | **PARTIAL** | Local platform abstraction + leaderboard persistence implemented; native platform API pending. |

### Remaining External Integrations

- Steamworks/native platform SDK wiring for achievements.
- Native platform leaderboard backend wiring.
- Real cloud save backend integration (beyond local mirror fallback).

### Implementation Changelog (This Pass)

- Added telemetry service and HUD telemetry overlay.
- Added in-run pause/settings/controls/tutorial/result overlays.
- Added procedural audio system with gameplay/boss layering and full SFX hooks.
- Added save slots, leaderboard persistence, endless mode, loadouts, and daily modifier state.
- Added new enemy movement types, new pattern resource types, and two additional boss definitions.
- Added QA tool scenes/scripts for wave integration, automated play, save verification, and visual regression.
- Added platform abstraction service with local fallback behavior for achievements and leaderboard submission.

---

## Summary

| Status | Count |
|--------|-------|
| **IMPLEMENTED** | 25 |
| **PARTIAL** | 3 |
| **PENDING** | 0 |
| **TOTAL TRACKED** | 28 |

**Recommended Focus:** Finish native SDK integrations (Steam/platform leaderboards, platform achievements, external cloud save provider) and then harden with runtime validation on target hardware.

---

## Appendix: Implemented Features (Reference)

For context, the following features **are** fully implemented:

- Player triangle ship with 9 archetype upgrades (Vector, Orbit, Pulse, Fractal, Entropy, Sustain, Crit, Shield, Chaos)
- 40+ upgrade cards fully functional
- 9 enemy movement types
- Boss system with multi-phase encounters
- Wave-based arena progression
- Upgrade selection (3 random cards)
- Meta currency system
- Save system
- HUD (HP, score, arena, wave announcements)
- Meta menu (title, currency, unlock buttons)
- Bullet manager with 4000 pooled bullets
- Collision system
- Pattern executor (spiral, radial burst)
- RNG determinism testing tools
- Stat math utilities
- Bullet stress test tools

---

*Document Version: 1.1*  
*Last Updated: 2026-03-02*  
*Project: Polychrome Void*
