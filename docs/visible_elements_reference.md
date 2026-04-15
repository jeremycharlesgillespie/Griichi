# Riichi Mahjong — Visible Game Elements Reference

Compiled from Wikipedia, riichi.wiki, and mahjong.guide. This is the reference
for what a digital mahjong UI must display to the player.

## 1. The Wall

**Structure:** 136 tiles arranged into 4 walls, each 2 tiles tall × 17 tiles wide.
- 26 stacks form the initial hands
- 7 stacks (14 tiles) form the **dead wall**
- Remaining 35 stacks (70 tiles) form the **live wall** from which players draw

**Visible state:** All wall tiles are face-down during play. The wall visibly
shrinks as tiles are drawn.

## 2. Dead Wall

**Position:** Typically displayed at top-left or in a corner of the screen.
**Contents (14 tiles):**
- **Rinshanpai** (kan replacement tiles): 4 tiles
- **Dora indicators:** up to 5 (1 initial + 4 possible kan dora)
- **Uradora indicators:** 5 (hidden — only revealed on riichi win)

**Visible:** The dead wall outline is visible. The dora indicator(s) are face-up.

## 3. Dora Indicator

**Initial:** 1 face-up tile on top of the dead wall (the upper tile of the
third stack from the back end of the dead wall).
**How it works:** The dora indicator shows the tile *before* the dora — so a
3-sou indicator means 4-sou is dora.
**Kan dora:** Each time a kan is called, the next dora indicator is flipped
face-up (up to 5 total).

## 4. Player Hands

**Own hand (14 tiles when about to discard, 13 otherwise):** Face-up, bottom
of the screen, arranged left-to-right. The newest drawn tile is usually
separated slightly on the right.
**Opponent hands:** Face-down tiles showing count only. The number of visible
tiles shrinks when opponents make calls (pon/chii/kan).

## 5. Discard Pond

**Position:** Directly in front of each player, centered on their side of the
table.
**Layout:** Tiles placed face-up in order of discard. Arranged in **rows of 6**.
7th discard starts a new row below; 13th starts a third row. Final shape:
~6 wide × 3 deep.
**Rotation:** A discard made while declaring riichi is placed **sideways**
(rotated 90°) to mark when riichi happened.

## 6. Called Melds (Open Sets)

**Position:** Placed to the right of each player's hand (or in a designated
meld area).
**Rotation of called tile:** The tile taken from a discard is **rotated 90°**
and its position indicates who discarded it:
- **Left of meld** → taken from left (kamicha)
- **Middle of meld** → taken from across (toimen)
- **Right of meld** → taken from right (shimocha)
**Closed kan:** All 4 tiles face-down (or the middle 2 face-down, edges face-up).
**Late kan (shouminkan):** The 4th tile is stacked on top of the corresponding
tile in the existing pon.

## 7. Riichi Stick

When a player declares riichi, a **1000-point stick is placed horizontally**
in front of them (usually across the first row of their pond). This stick
remains until someone wins — the winner collects it plus any previous unclaimed
riichi sticks.

## 8. Seat Wind

Each player has a seat wind (E/S/W/N). **East is the dealer.** The seat wind
rotates each hand (counter-clockwise: E→N→W→S→E). The wind is typically shown
as a label next to each player's score/name.

## 9. Round Wind

The current **round wind** (East/South) is displayed in a central or fixed UI
position. East round is 4 hands; games can be East-only (tonpuusen) or
East+South (hanchan).

## 10. Score Display

Each player's current point total is shown near their name/position. Start:
25,000 points. Changes occur after each hand.

## 11. Round/Hand Counter

Shows current round (East/South) and hand number (1-4). Format: "East 1",
"South 3", etc. Also shows honba counter (repeat round marker).

## 12. Honba Counter (Repeat Markers)

When the dealer wins or draws tenpai, the next hand is a "renchan" (bonus
hand). **100-point sticks** placed in the dealer's area indicate the honba
count — each adds 300 points to the winning hand (or 100 per player on tsumo).

## 13. Dealer Marker

A small marker (traditionally a die or dedicated indicator) shows which
player is the current dealer. Alternative: the seat with East wind is the dealer.

## 14. Tiles Remaining Counter

How many tiles are left in the live wall. When this reaches 0, the hand is
an exhaustive draw.

## 15. Action Buttons (Call UI)

When opportunities arise, the player must be shown:
- **Chii** — with the specific tile combinations available (if multiple)
- **Pon**
- **Kan** (open, closed, or late)
- **Riichi** — only when in tenpai, closed hand, and 4+ tiles left in wall
- **Tsumo** — self-draw win
- **Ron** — discard win
- **Pass/Skip** — decline all calls

## 16. Hand Information (Helper UI, optional)

Common helper displays in digital games:
- **Shanten count** — how many tiles away from tenpai
- **Waiting tiles** — which tiles would complete the hand when tenpai
- **Yaku preview** — what yaku the current hand qualifies for
- **Furiten indicator** — warns when hand is in furiten

## 17. Center of the Table

Usually empty (this is where tiles go during draws). Some digital displays
show:
- The current dealer arrow/marker
- The round wind
- Honba counter
- Riichi sticks (pooled in center)

## What GRiichi Currently Shows vs. Missing

**Currently shows:**
- Player hand (face-up, bottom)
- Opponent hand tile counts (face-down, 3 sides)
- Discard ponds (but overlapping — needs fix)
- Round/hand in top-left
- Tiles remaining in top-right
- Scores in top-left
- Shanten count in bottom-left
- Waiting tiles (when tenpai)
- Call buttons

**Missing:**
- Dora indicator display
- Dead wall visualization
- Live wall visualization
- Riichi sticks (visual placement when declared)
- Called melds display (pon/chii/kan visible beside each player)
- Honba counter
- Dealer marker
- Seat wind labels per player
- Riichi-sideways rotation in pond
- Call button context (which tiles the chii would use)

## Sources
- [Japanese Mahjong — Wikipedia](https://en.wikipedia.org/wiki/Japanese_mahjong)
- [A Beginner's Guide to Riichi Mahjong](https://mahjong.guide/a-beginners-guide-to-riichi-mahjong/)
- [Game Rules — R Mahjong](https://riichimahjong.net/rules/)
