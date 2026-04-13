# CLAUDE.md — GRiichi project orientation

## What this project is

GRiichi is a Japanese Mahjong (Riichi) game built in Godot 4 with
GDScript. It's a fresh port of OpenRiichi (a Vala/SDL/OpenGL client
from 2020 that was revived for macOS in 2026). The game logic is
ported from the Vala codebase; rendering and UI are built natively
in Godot.

## Project structure

```
scripts/
  game_logic/    # Pure game rules: tiles, hands, yaku, scoring
    tile.gd      # TileType enum, Tile class, name formatters
    tile_rules.gd # Hand analysis, shanten, yaku detection, scoring
    round_state.gd # Single-round game state (wall, hands, calls)
    game_state.gd  # Multi-round tournament state
  bots/          # AI players
  ui/            # UI controller scripts
scenes/          # Godot .tscn scene files
assets/          # Textures, models, audio, fonts
```

## Source of truth for game rules

The Vala codebase at /Users/gman/code/OpenRiichi is the reference
implementation. When porting, translate the logic line-by-line from
Vala to GDScript. Don't redesign the rules — they're correct and
have been tested via gameplay.

Key files to reference:
- TileRules.vala → tile_rules.gd (hand_readings, yaku, scoring, shanten)
- RoundState.vala → round_state.gd
- SimpleBot.vala / HardBot.vala → bots/
- Tile.vala → tile.gd (already ported)

## Conventions

- GDScript, not C#
- Godot 4.6 features are available
- Follow the user's global CLAUDE.md: explicit > implicit, debuggable,
  no speculative abstractions, early returns
- Use typed GDScript (type hints on all function signatures)
- Use class_name for all scripts that need to be referenced by others
