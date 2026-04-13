# GRiichi — Development Status & Next Steps

## What's Done (2026-04-13)

### Core Game Logic — COMPLETE, 21 tests passing
- `scripts/game_logic/tile.gd` — TileType enum (34 types), Tile class, name formatters, wind helpers, dora indicator
- `scripts/game_logic/hand_data.gd` — TileMeld, TilePair, HandReading, RoundStateCall data classes
- `scripts/game_logic/tile_rules.gd` — The big one:
  - `hand_readings()` — recursive hand decomposition (standard 4-melds+pair, chiitoi 7-pairs, kokushi)
  - `in_tenpai()`, `winning_hand()`, `can_win_with()`
  - `get_shanten()` — coarse bucket (0=tenpai, 1=iishanten, 2+=far)
  - `waiting_tiles()` — list of tile types that complete a tenpai hand
  - `can_pon()`, `can_chii()`, `get_chii_groups()`, `can_open_kan()`
  - `in_furiten()`, `can_void_hand()`
- `scripts/tests/test_tile_rules.gd` — 21 automated tests, all passing

### Project Infrastructure
- Godot 4.6 project file configured (1280x720, forward+ renderer, 2x MSAA)
- Main menu scene skeleton (`scenes/main_menu.tscn`) — title + Singleplayer/Quit buttons
- CLAUDE.md with project orientation
- .gitignore for Godot
- Initial git commit on master

### How to Run Tests
```bash
cd ~/code/GRiichi
godot --headless --editor --quit-after 3   # scan project (needed once)
godot --headless --script res://scripts/tests/test_tile_rules.gd
```

---

## What's Next — BUILD ORDER

### Step 1: 3D Game Scene (table + tiles + camera)
Create `scenes/game.tscn` with:
- A flat green table (MeshInstance3D with a BoxMesh or plane)
- Camera looking down at an angle (like the player's perspective)
- Tile mesh: a small rectangular box (~0.03 x 0.04 x 0.02) with face texture
- Tile textures: for now, use colored rectangles or simple labels — real art can come later
- Wire the Singleplayer button to load this scene

### Step 2: RoundState (game flow)
Create `scripts/game_logic/round_state.gd`:
- Tile wall: create all 136 tiles (4 of each of 34 types), shuffle
- Deal 13 tiles to each of 4 players
- Draw/discard cycle: current player draws → discards → next player
- Track whose turn it is, which tiles are in each player's hand/pond
- Port from OpenRiichi's `source/Game/Logic/RoundState.vala`

### Step 3: Player Hand Display
- Render the local player's 13-14 tiles as 3D objects along the bottom
- Tiles face up (player can see them)
- Click a tile to select it for discard
- Highlight on hover (like the Vala version's RenderTile.hovered)
- After discard, tile moves to the pond (center area)

### Step 4: Bot Players
Port from OpenRiichi:
- `scripts/bots/bot.gd` — base class
- `scripts/bots/null_bot.gd` — always discards first tile
- `scripts/bots/simple_bot.gd` — basic heuristics (keep pairs, discard isolated tiles)
- `scripts/bots/hard_bot.gd` — chii calls, genbutsu safety, riichi guard
- Bots run on a timer (short delay to simulate thinking)

### Step 5: HUD & UI
Using Godot's proper UI system (finally!):
- **Shanten counter** — Label node, updates each draw/discard
- **Waits display** — shows when tenpai
- **Action buttons** — Pon, Chii, Kan, Riichi, Tsumo, Ron (show/hide based on state)
- **Tile tooltip** — on hover, show readable name via RichTextLabel
- **Timer** — decision countdown
- **Score display** — player scores in corners

### Step 6: Features from Vala version
- Coach (Claude -p integration) — use RichTextLabel with BBCode for scrollable response!
- Yaku Guide / Points Guide / Glossary — RichTextLabel + ScrollContainer (the thing Vala couldn't do)
- Difficulty selector (Easy/Medium/Hard bot picker)
- Game logging / replay

---

## Reference: Vala Codebase
The original OpenRiichi code is at `/Users/gman/code/OpenRiichi`.
Key files to reference when porting:
- `source/Game/Logic/RoundState.vala` → round_state.gd
- `source/Game/Logic/GameState.vala` → game_state.gd (multi-round)
- `source/GameServer/Bots/SimpleBot.vala` → simple_bot.gd
- `source/GameServer/Bots/HardBot.vala` → hard_bot.gd
- `source/GameServer/Server/ServerMenu.vala` → game setup flow
- `source/Game/Rendering/` → replaced by Godot scenes

## Key Architectural Decisions
- GDScript (not C#)
- All game logic in `scripts/game_logic/` — pure computation, no Godot dependencies
- All UI in `scripts/ui/` — Godot Control nodes
- All bots in `scripts/bots/`
- Scenes in `scenes/`
- Assets in `assets/`
- Tests in `scripts/tests/` — run via `godot --headless --script`
