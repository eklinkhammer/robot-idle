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

## Milestone 1: Core TD Loop (Current)

Build a single TD screen that answers: *is placing towers and watching waves fun?*

### Features
| Feature | Status |
|---|---|
| 20x11 grid with AStar pathfinding | Done |
| Maze-building tower placement (blocks path = rejected) | Done |
| Blocked-placement red flash feedback | Done |
| Tower removal via popup menu | Done |
| Enemies walking the AStar path | TODO |
| Towers detect + shoot enemies in range | TODO |
| 3 tower types: cheap/fast, slow/strong, AoE | TODO |
| 5 waves of enemies, 2 traits (normal, fast) | TODO |
| "Send Wave" button + wave counter UI | TODO |
| Basic economy: earn currency on kill, spend on towers | TODO |

### Enemy Design (Milestone 1)
- **Normal**: standard speed, standard HP
- **Fast**: 2x speed, lower HP

### Tower Design (Milestone 1)
- **Peasant (cheap/fast)**: low damage, high fire rate, short range
- **Archer (slow/strong)**: high damage, slow fire rate, long range
- **Catapult (AoE)**: medium damage in area, slow fire rate, medium range

---

## Milestone 2: Economy + Progression

- Currency earned from kills, lost when enemies reach exit
- Tower costs and refund on removal (partial refund)
- Lives system (enemies reaching exit reduce lives)
- Win/lose conditions
- Tower upgrades (1-2 upgrade tiers per tower type)

---

## Milestone 3: Campaign Map (Idle Layer)

- Overworld grid/map with buildable plots
- Buildings produce resources over real time (idle mechanic)
- Buildings unlock tower types and set caps
- "Return to battle" flow: campaign → pick level → TD battle → rewards → campaign
- Offline progress calculation on app open

---

## Design Principles
- **Waves are snack-sized** (~30-60s each). Prep between waves has no timer.
- **Mazing is the skill expression**. Pathing shapes are the player's creative output.
- **Idle payoff must be obvious**. "Your farms produced 200 grain → 2 more peasant towers available."
- **Start narrow**. 3-4 tower types max until those feel good. Vary enemies before adding towers.
- **Enemy variety drives tower choice**. Fast, armored, flying, split-on-death — these make tower selection matter.
