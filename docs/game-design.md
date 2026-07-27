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
