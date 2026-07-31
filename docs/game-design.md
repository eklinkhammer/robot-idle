# Robot Idle TD — Game Design

## Vision
A mobile TD game inspired by Wintermaul with an idle campaign layer. Players build towers to maze enemies in short TD battles, while an overworld campaign map generates resources over time and unlocks new tower types.

## Architecture

### Two Layers
1. **TD Battle** — Real-time tower defense with maze-building (Wintermaul-style). Short sessions (~30-60s waves). Player places towers to shape enemy pathing, then sends waves.
2. **Campaign Map** — Idle/incremental layer. Players build structures (farms, blacksmiths, etc.) that produce resources over time and unlock tower types for TD battles.

### Campaign → Tower Pipeline
- Campaign buildings unlock tower types for battle (e.g., 4 farms → peasant towers, blacksmith → arrow towers)
- Buildings can set a **cap** (max N towers of that type per battle) or simply **unlock** the type
- Optional: player picks a **loadout** of unlocked towers before each battle (deckbuilding layer)

---

## Milestone 1: Core TD Loop — DONE

Build a single TD screen that answers: *is placing towers and watching waves fun?*

### Features
| Feature | Status |
|---|---|
| 20x11 grid with AStar pathfinding | Done |
| Maze-building tower placement (blocks path = rejected) | Done |
| Blocked-placement red flash feedback | Done |
| Tower removal via popup menu | Done |
| Enemies walking the AStar path | Done |
| Towers detect + shoot enemies in range | Done |
| 3 tower types: cheap/fast, slow/strong, AoE | Done |
| 5 waves of enemies, 2 traits (normal, fast) | Done |
| "Send Wave" button + wave counter UI | Done |
| Basic economy: earn currency on kill, spend on towers | Done |
| Win/lose conditions | Done |

---

## Milestone 2: Polish + Replayability — DONE

### Features
| Feature | Status |
|---|---|
| Tower upgrades (1 tier per type) | Done |
| 3 battle maps (Plains, Valley, Siege) | Done |
| Armored enemy type | Done |
| Replay loop (Restart/Main Menu buttons) | Done |
| Multi-spawn support (Map 3) | Done |
| Map selection screen | Done |
| Beaten maps tracking (in-memory) | Done |

### Tower Upgrades (1 tier each)
| Tower | Stat Changes | Upgrade Cost | New Refund |
|---|---|---|---|
| Peasant | damage 8→14, fire_rate 4.0→5.5 | 15g | 12g |
| Archer | damage 40→65, range 224→288 | 35g | 30g |
| Catapult | damage 25→40, aoe 80→112 | 50g | 45g |

### Enemy Types
| Type | Speed | HP | Color | Gold |
|---|---|---|---|---|
| Normal | 100 | 100 | Orange | 10g |
| Fast | 200 | 50 | Yellow-Green | 10g |
| Armored | 60 | 300 | Dark Gray | 15g |

### Map Definitions
- **Plains**: Spawn (0,5) → Exit (19,5). 5 waves, 20 lives, 100g. No obstacles.
- **Valley**: Spawn (0,0) → Exit (19,10). 6 waves, 20 lives, 120g. 9 obstacle cells (3 wall segments). Armored from wave 3.
- **Siege**: Spawns (0,2)+(0,8) → Exit (19,5). 7 waves, 15 lives, 150g. 14 obstacle cells. Multi-spawn, hardest map.

### Key Design Decisions
- Upgrade cap is a var (`upgrade_cap = -1` means unlimited). M3 campaign will set per-battle.
- Maps are data-driven so campaign can define maps per territory.
- Multi-spawn uses round-robin cycling.
- Spawn queue is shuffled so enemy types are intermixed.
- Gold reward lives on enemy instance so types can give different amounts.

### Procedural Maps — Done
Infinite replayability via `MapGenerator` which produces a valid `MapData` from a seed + difficulty (1-5). Accessible from the map select screen.

#### Generation Algorithm
- **Spawns**: Column 0. Count scales with difficulty: 1 (diff 1-2), 2 (diff 3-4), 3 (diff 5). Evenly spaced vertically with RNG jitter.
- **Exit**: Column 19, random row weighted toward center.
- **Obstacles**: `2 + difficulty` wall segments (3-7 attempts). 60% horizontal (3-6 cells wide), 40% vertical (3-5 cells tall). Placed across 4 horizontal zones (cols 3-6, 7-10, 11-14, 15-17). Purpose: break up spirals and limit how long a single tower stays useful. Each segment validated with AStarGrid2D — skipped if it blocks any spawn→exit path.
- **Waves**: `4 + difficulty` waves (5-9). Base enemies `8 + difficulty * 2`, scaling 1.35x per wave. Fast enemies delayed at low difficulty (wave 4 at diff 1, wave 1 at diff 5). Armored enemies delayed similarly (wave 5 at diff 1, wave 2 at diff 5).
- **Economy**: Starting gold `80 + difficulty * 20`. Lives `25 - difficulty * 2` (min 10). Wave gold `25 + difficulty * 5 + wave_index * 10`, last wave = 0.

#### Difficulty Scaling
| Difficulty | Spawns | Obstacles | Waves | Total Enemies | Fast/Armored % | Lives | Start Gold |
|---|---|---|---|---|---|---|---|
| 1 | 1 | ~11 | 5 | 100 | 14% / 5% | 23 | 100g |
| 2 | 1 | ~14 | 6 | 174 | 26% / 16% | 21 | 120g |
| 3 | 2 | ~18 | 7 | 288 | 39% / 25% | 19 | 140g |
| 4 | 2 | ~22 | 8 | 459 | 42% / 29% | 17 | 160g |
| 5 | 3 | ~27 | 9 | 715 | 44% / 32% | 15 | 180g |

Diff 1 is easier than Plains; Diff 5 is harder than Siege.

#### Seed & Restart Behavior
- Selecting "Generate & Play" sets seed to -1. On battle start, `td_battle.gd` assigns `randi()` and stores it in `GameState.procedural_seed`.
- Restart (`reload_current_scene()`) reuses the same seed → same map layout.
- Returning to map select resets seed to -1 → next play generates a new map.
- Highest difficulty beaten is tracked in `GameState.highest_procedural_difficulty_beaten`.

### Offense Mode (Attack Fortress) — Done
PvE offense mode where the player attacks a procedurally generated fortress. Reverses the TD formula: instead of placing towers, the player draws paths through pre-built defenses and chooses unit composition.

#### Core Flow
1. **Preview**: See the fortress layout — spine walls divide the grid into 2-3 lanes, each with pre-placed towers and a distinct threat profile.
2. **Draw Paths** (Step 1): Click entry cells (column 0) to start, click adjacent walkable cells to extend toward the exit (column 19). Right-click to undo. Can draw 1 path per lane.
3. **Assign Units** (Step 2): For each completed path, build an ordered spawn queue using +N/+F/+A buttons. Units deploy in the chosen order. Total units limited by budget.
4. **Battle**: All paths deploy simultaneously. Towers fire as in defense mode. Win if enough units reach the exit.

#### Fortress Generation (`fortress_generator.gd`)
- **Spine Walls**: Long horizontal obstacle walls divide the grid into lanes. Each spine spans cols 2-17 with exactly one gap (1-2 cells wide). Gaps staggered by 4+ columns between spines.
- **Internal Obstacles**: 1-3 short segments (2-4 cells) per lane for local S-curves. Validated with AStarGrid2D.
- **Threat Profiles**: Each lane gets a distinct composition:
  - *Anti-Single* (Archers): High per-hit damage, weak against fast units rushing past
  - *Anti-Swarm* (Catapults): AoE damage, weak against armored units with high HP
  - *Light* (Peasants): Low threat, fewer towers, longer path
- **Tower Placement**: Budget `120 + difficulty * 60` gold. Light lane gets 15-25% of budget. Towers placed adjacent to each lane's A* path. Each placement validated to not block any entry→exit path.
- **Upgrades**: At difficulty 3+, some towers are pre-upgraded (3-10 depending on difficulty).

#### Difficulty Scaling
| | Diff 1 | Diff 2 | Diff 3 | Diff 4 | Diff 5 |
|---|---|---|---|---|---|
| Lanes | 2 | 2 | 3 | 3 | 3 |
| Tower budget | 180g | 240g | 300g | 360g | 420g |
| Upgrades | 0 | 0 | 3-4 | 5-6 | 8-10 |
| Gap width | 2 | 2 | 1-2 | 1 | 1 |
| Internal obs/lane | 1 | 1-2 | 2 | 2-3 | 3 |
| Unit budget | 20 | 25 | 30 | 35 | 40 |
| Win threshold | 3 | 4 | 5 | 6 | 7 |

#### Tactical Depth
- **Lane selection**: Towers in lane A can't help lane C. Sending a decoy down a heavy lane while the real force takes the light lane is valid.
- **Unit ordering**: Units spawn in the exact order the player queues them. Leading with armored to absorb tower fire, then sending fast units through the gap is a real tactic.
- **Counter-matching**: Archers are weak vs fast (rush past slow fire rate), catapults are weak vs armored (low DPS vs high HP). Reading the lane profiles and picking the right unit type is the puzzle.

#### Seed & Restart Behavior
- Same pattern as procedural defense: seed -1 on new game, assigned on battle start, preserved on restart, reset on return to menu.
- Highest offense difficulty beaten tracked in `GameState.highest_offense_difficulty_beaten`.

#### New Files
- `fortress_data.gd` — Data container (entry cells, obstacles, towers, lanes, budget, threshold)
- `fortress_generator.gd` — Spine walls, lane detection, tower placement, validation
- `path_drawer.gd` — Click-to-draw path input with undo, multi-path, lane labels
- `offense_battle.gd` + `offense_battle.tscn` — Two-phase battle orchestrator

#### Modified Files
- `enemy.gd` — Added `initialize_fixed_path()` for following pre-drawn paths without A* repathing
- `grid_manager.gd` — Added `configure_fortress()` to render pre-placed towers; fortress mode disables player tower placement
- `game_state.gd` — Added `offense_difficulty`, `offense_seed`, `highest_offense_difficulty_beaten`
- `map_select.gd` — Added "Attack Fortress" section with difficulty selector

---

## Milestone 3: Campaign Map (Idle Layer)

- Overworld grid/map with buildable plots
- Buildings produce resources over real time (idle mechanic)
- Buildings unlock tower types and set caps
- "Return to battle" flow: campaign → pick level → TD battle → rewards → campaign
- Offline progress calculation on app open

### Variable Battle Maps
- Each campaign node/level defines its own battle map configuration
- Non-uniform grids: different dimensions, pre-placed obstacles, terrain
- Variable spawn/exit points (multiple spawns, different edges, mid-map exits)
- Forces players to adapt mazing strategy per level — no single layout works everywhere
- Map variety driven by campaign progression (early = simple, later = complex layouts)

---

## Resource Loop & Territory Expansion

The core idle loop: earn resources → invest in one of three sinks:

1. **Resource buildings** — More/better production (compound growth). Farms, mines, lumber mills, etc.
2. **Tower upgrades** — Permanent upgrades that apply in and out of battle. Upgrade tiers, new tower types, stat boosts that persist across battles.
3. **Units / Army** — Spend resources to recruit units that conquer new territory (building slots). Territories are not free — you fight for them or send units to claim them.

### Territory System
- The overworld is divided into territories, each with limited building slots
- Acquiring new territory requires spending units/resources (auto-battle or TD battle)
- Each territory has a **unique battle map** — different grid size, obstacles, spawn/exit layout
- Expanding territory = more building slots + new battle maps to play
- Creates a natural progression: produce → expand → produce more → expand further

---

## Design Principles
- **Waves are snack-sized** (~30-60s each). Prep between waves has no timer.
- **Mazing is the skill expression**. Pathing shapes are the player's creative output.
- **Idle payoff must be obvious**. "Your farms produced 200 grain → 2 more peasant towers available."
- **Start narrow**. 3-4 tower types max until those feel good. Vary enemies before adding towers.
- **Enemy variety drives tower choice**. Fast, armored, flying, split-on-death — these make tower selection matter.
