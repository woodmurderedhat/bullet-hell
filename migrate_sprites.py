#!/usr/bin/env python3
"""
Migrate enemy and boss .tres files from the old single-sprite schema to
the new per-state sprite schema (idle / move / hit / death).

Run once from the repo root:
  python3 migrate_sprites.py
"""

import os
import re

GAME_ROOT = os.path.join(
    os.path.dirname(__file__),
    "polychrome-void", "polychrome-void",
)

# ---------------------------------------------------------------------------
# Sprite set mappings  (entity id → sprite-set folder name)
# ---------------------------------------------------------------------------

ENEMY_SPRITE_MAPPING: dict[str, str] = {
    "basic_square":         "basic_1",
    "burst_square":         "basic_2",
    "dash_spike":           "basic_3",
    "kiting_shard":         "basic_4",
    "strafer_diamond":      "basic_4",
    "sentry_core":          "basic_5",
    "dash_burst_brute":     "medium_1",
    "strafe_spiral_node":   "medium_1",
    "elite_flanker_01":     "medium_2",
    "elite_flanker_02":     "medium_2",
    "orbit_burst_node":     "medium_2",
    "orbit_hex":            "medium_3",
    "elite_interceptor_01": "medium_3",
    "apex_orbit_01":        "medium_3",
    "wave_kite":            "medium_4",
    "elite_zoner_01":       "medium_4",
    "apex_kiting_01":       "medium_4",
    "elite_splitter_01":    "medium_1",
    "elite_hunter_01":      "heavy_1",
    "apex_dash_01":         "heavy_1",
    "elite_suppressor_01":  "heavy_2",
    "apex_sentry_01":       "heavy_2",
    "apex_zigzag_01":       "heavy_3",
}

BOSS_SPRITE_MAPPING: dict[str, str] = {
    "boss_01": "boss_1",
    "boss_02": "boss_1",
    "boss_03": "boss_1",
    "boss_04": "boss_1",
    "boss_05": "boss_2",
    "boss_06": "boss_2",
    "boss_07": "boss_2",
    "boss_08": "boss_2",
}

# ---------------------------------------------------------------------------
# Regex patterns for old fields that must be stripped from .tres files.
# ---------------------------------------------------------------------------

_OLD_FIELD_RE = re.compile(
    r"^(sprite_texture_path|sprite_region_origin|sprite_frame_count|sprite_fps"
    r"|sprite_idle_path|sprite_move_path|sprite_hit_path|sprite_death_path"
    r"|hit_state_duration|death_state_duration)\s*=.*$",
    re.MULTILINE,
)

_ID_RE = re.compile(r'^id\s*=\s*&"([^"]+)"', re.MULTILINE)


def _extract_id(content: str) -> str | None:
    m = _ID_RE.search(content)
    return m.group(1) if m else None


def _make_sprite_block(sprite_set: str, asset_domain: str) -> str:
    base = f"res://assets/sprites/{asset_domain}/{sprite_set}"
    return (
        f'sprite_idle_path = "{base}/{sprite_set}_idle.png"\n'
        f'sprite_move_path = "{base}/{sprite_set}_move.png"\n'
        f'sprite_hit_path = "{base}/{sprite_set}_hit.png"\n'
        f'sprite_death_path = "{base}/{sprite_set}_death.png"\n'
        f"hit_state_duration = 0.1\n"
        f"death_state_duration = 0.25"
    )


def migrate_tres(filepath: str, id_map: dict[str, str], asset_domain: str) -> None:
    with open(filepath, encoding="utf-8") as f:
        content = f.read()

    entity_id = _extract_id(content)
    if not entity_id:
        print(f"  SKIP (no id field):          {os.path.basename(filepath)}")
        return

    sprite_set = id_map.get(entity_id)
    if not sprite_set:
        print(f"  SKIP (unmapped id '{entity_id}'): {os.path.basename(filepath)}")
        return

    # Remove all old and previously-written sprite fields in one pass.
    content = _OLD_FIELD_RE.sub("", content)

    # Collapse runs of blank lines left by the removals (max two in a row).
    content = re.sub(r"\n{3,}", "\n\n", content)

    new_block = _make_sprite_block(sprite_set, asset_domain)

    # Insert before the first anchor line present in the file.
    inserted = False
    for anchor in ("score_value", "phases"):
        pattern = re.compile(rf"^({anchor}\s*=)", re.MULTILINE)
        if pattern.search(content):
            content = pattern.sub(new_block + r"\n\1", content, count=1)
            inserted = True
            break

    if not inserted:
        # Fall back: append at end of [resource] section.
        content = content.rstrip("\n") + "\n" + new_block + "\n"

    with open(filepath, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"  OK  [{entity_id:25s} → {sprite_set}]  {os.path.basename(filepath)}")


def main() -> None:
    enemy_dir = os.path.join(GAME_ROOT, "data", "enemies")
    boss_dir = os.path.join(GAME_ROOT, "data", "bosses")

    print("=== Migrating enemy .tres files ===")
    for fname in sorted(os.listdir(enemy_dir)):
        if fname.endswith(".tres"):
            migrate_tres(os.path.join(enemy_dir, fname), ENEMY_SPRITE_MAPPING, "enemies")

    print("\n=== Migrating boss .tres files ===")
    for fname in sorted(os.listdir(boss_dir)):
        if fname.endswith(".tres"):
            migrate_tres(os.path.join(boss_dir, fname), BOSS_SPRITE_MAPPING, "bosses")

    print("\nDone.")


if __name__ == "__main__":
    main()
