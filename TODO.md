# GRiichi — Development Status & Next Steps

## What's Done (2026-04-14)

### Core Game Logic — COMPLETE, 47 tests passing
- `scripts/game_logic/tile.gd` — TileType enum (34 types), Tile class, name formatters, wind helpers, dora indicator
- `scripts/game_logic/hand_data.gd` — TileMeld, TilePair, HandReading, RoundStateCall data classes
- `scripts/game_logic/tile_rules.gd` — Hand decomposition, tenpai/shanten/waits, chiitoi, kokushi, call eligibility, furiten
- `scripts/game_logic/round_state.gd` — Single-round state machine: draw/discard cycle, calls (pon/chii/kan), riichi, ron/tsumo, draw conditions
- `scripts/game_logic/round_state_wall.gd` — 136-tile wall, shuffle, dead wall, dora indicator management
- `scripts/game_logic/round_state_player.gd` — Player state: hand, pond, calls, riichi, furiten, discard validation (kuikae)
- `scripts/game_logic/game_state.gd` — Multi-round management: scoring (tsumo/ron/draw), dealer rotation, wind progression, han/fu calculation

### Bot AI
- `scripts/bots/bot.gd` — Base class with default behaviors
- `scripts/bots/simple_bot.gd` — Mid-tier bot: tenpai preservation, useless honor dumps, isolated tile detection, yakuhai-only pon calls

### 3D Game Scene
- `scenes/game.tscn` — 3D table, camera at player perspective, lighting, environment
- `scripts/ui/game_controller.gd` — Full game orchestration: draw/discard cycle, bot turns, call decisions, tile rendering (3D boxes with Label3D), mouse hover/click, round flow

### HUD
- `scripts/ui/game_hud.gd` — Score display, shanten counter, waiting tiles, call action buttons (Tsumo/Ron/Pon/Chii/Kan/Riichi/Skip), round result panel, game over screen

### Menu → Game Flow
- `scenes/main_menu.tscn` — Singleplayer button loads game scene
- Full round loop: deal → draw/discard → calls → win/draw → score → next round

### Tests — 47 passing
- `scripts/tests/test_tile_rules.gd` — 21 tests (tile basics, pon, chii, winning, tenpai, shanten, waits, chiitoi, kokushi)
- `scripts/tests/test_round_state.gd` — 23 tests (wall, dealing, draw/discard, pon, riichi, tsumo, game state)
- `scripts/tests/test_game_scene.gd` — 3 tests (full bot round simulation with scoring)

### How to Run Tests
```bash
cd ~/code/GRiichi
godot --headless --script res://scripts/tests/test_tile_rules.gd
godot --headless --script res://scripts/tests/test_round_state.gd
godot --headless --script res://scripts/tests/test_game_scene.gd
```

---

## What's Next — Polish & Features

### Step 1: Visual Polish
- Tile textures: proper mahjong tile face images instead of colored boxes + labels
- Tile animations: smooth draw/discard/call movement with tweens
- Opponent hand display: show face-down tiles for other players
- Called melds display: show open melds beside each player's pond
- Table center: compass showing current wind and turn indicator

### Step 2: Full Yaku Detection
Port remaining yaku from TileRules.vala (currently simplified):
- Toitoi, honitsu, chinitsu, san ankou, ittsu, chanta, junchan
- Sankantsu, suu ankou, chinroto, tsuuiisou, ryuuiisou, etc.
- Full fu calculation (currently simplified to 30 fu)

### Step 3: HardBot
- Smart chii calling (shanten reduction + yaku path check)
- Threat-aware discard (genbutsu safety scoring)
- Riichi guard (dead-wait detection, deal-in risk)

### Step 4: Advanced Features
- Coach (Claude -p integration) — RichTextLabel with BBCode for scrollable AI advice
- Yaku Guide / Points Guide / Glossary — RichTextLabel + ScrollContainer
- Difficulty selector (Easy/Medium/Hard bot picker)
- Game logging / replay
- Sound effects

---

## Reference: Old Vala Codebase
- `source/Game/Logic/TileRules.vala` → tile_rules.gd (yaku detection still needs full port)
- `source/Game/Logic/RoundState.vala` → round_state.gd (DONE)
- `source/Game/Logic/GameState.vala` → game_state.gd (DONE)
- `source/GameServer/Bots/SimpleBot.vala` → simple_bot.gd (DONE)
- `source/GameServer/Bots/HardBot.vala` → hard_bot.gd (NOT YET)
