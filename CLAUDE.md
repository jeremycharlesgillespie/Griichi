# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this project is

GRiichi is a Japanese Mahjong (Riichi) game built in Godot 4.6 with GDScript for GoDot.

## Commands

### Run all tests
```bash
godot --headless --script res://scripts/tests/test_tile_rules.gd
godot --headless --script res://scripts/tests/test_round_state.gd
godot --headless --script res://scripts/tests/test_game_scene.gd
```

### Run a single test (edit _initialize to call only the desired test method)
Tests are methods on the SceneTree-extending script. To run one, temporarily
comment out other test calls in `_initialize()` of the test file.

### First-time project scan (required before headless test runs on a fresh clone)
```bash
godot --headless --editor --quit-after 3
```

### Launch the game
```bash
godot
```

## Architecture

### Separation: pure logic vs. Godot

All game rules live in `scripts/game_logic/` as pure GDScript with **no Godot
scene/node dependencies**. This keeps them testable via headless scripts. UI
scripts in `scripts/ui/` interact with Godot nodes. Bots go in `scripts/bots/`.

### Core classes (game_logic/)

- **Tile** (`tile.gd`) -- `TileType` enum (34 types), `Wind` enum, `Tile`
  instances with id/type/dora. Provides name formatters, type queries,
  `dora_indicator()` wrapping logic, and `sort_by_type()`.

- **HandData** (`hand_data.gd`) -- Pure data classes. Inner classes: `TileMeld`,
  `TilePair`, `HandReading` (melds + pairs + chiitoi/kokushi flags),
  `RoundStateCall` (call type + tiles + discarder).

- **TileRules** (`tile_rules.gd`) -- All-static utility class. Hand decomposition
  (`hand_readings`), tenpai/winning/shanten/waits detection, call eligibility
  (pon/chii/kan), furiten, void hand. Yaku detection is simplified -- see TODO.md
  for the full yaku port status.

- **RoundState** (`round_state.gd`) -- Single-round state machine. Manages
  current player, draw/discard cycle, call execution (pon/chii/kan), riichi,
  ron/tsumo, and draw conditions (empty wall, four kans, four riichi, four winds).

- **RoundStateWall** (`round_state_wall.gd`) -- 136-tile wall: shuffle, draw
  pile (122 tiles), dead wall (14 tiles), dora indicator management.

- **RoundStatePlayer** (`round_state_player.gd`) -- Player hand/pond/calls,
  riichi state, furiten (temporary + permanent), discard validation including
  kuikae restrictions after chii/pon.

- **GameState** (`game_state.gd`) -- Multi-round manager: scoring (tsumo/ron/draw
  tenpai payments), dealer rotation, wind progression, simplified han counting
  and base points calculation.

### Bots (bots/)

- **Bot** (`bot.gd`) -- Base class. Override `get_discard_tile()`,
  `should_call_pon()`, `get_chii_tiles()`, `should_declare_riichi()`.
- **SimpleBot** (`simple_bot.gd`) -- Discard heuristics (tenpai preservation,
  useless honor dumps, isolated tiles). Calls pon on yakuhai only.

### UI (scripts/ui/)

- **game_controller.gd** -- Game scene controller (extends Node3D). Orchestrates
  the full draw/discard cycle between human and bots. Renders tiles as 3D boxes
  with Label3D text. Handles mouse hover/click for tile selection.
- **game_hud.gd** -- HUD overlay (extends Control). Built programmatically in
  `_build_ui()`. Shows scores, shanten, waits, call buttons, round results.
- **main_menu.gd** -- Title screen. Singleplayer button loads game scene.

### Scene graph

- `scenes/main_menu.tscn` -- Entry point (set in project.godot). Title + buttons.
- `scenes/game.tscn` -- 3D game scene: table mesh, camera, lighting, HUD overlay,
  bot timer. Script: game_controller.gd.

### Test infrastructure

Tests extend `SceneTree` and run headless. Custom `assert_true()` / `assert_eq()`
helpers. Exit code = number of failures (0 = all pass). 47 tests across 3 files.

## Source of truth for game rules

implementation. When porting, translate logic line-by-line from Vala to
GDScript. Don't redesign the rules -- they are tested via gameplay.

Key Vala files and their GDScript targets:
- `source/Game/Logic/TileRules.vala` -> `tile_rules.gd` (core ported, full yaku TODO)
- `source/Game/Logic/RoundState.vala` -> `round_state.gd` (DONE)
- `source/Game/Logic/GameState.vala` -> `game_state.gd` (DONE, simplified scoring)
- `source/GameServer/Bots/SimpleBot.vala` -> `bots/simple_bot.gd` (DONE)
- `source/GameServer/Bots/HardBot.vala` -> `bots/hard_bot.gd` (not yet started)

## Conventions

- GDScript only (not C#). Godot 4.6 features are available.
- Typed GDScript: type hints on all function signatures and non-obvious variables.
- `class_name` on all scripts that are referenced by other scripts.
- All static methods on TileRules -- it is a utility class, not instantiated.
- Inner classes on HandData for data structures (TileMeld, TilePair, etc.).
- `RefCounted` as base for game logic classes (automatic memory management).
- See TODO.md for the detailed development roadmap.
