# Robot Idle TD

A tower defense game built with Godot 4.6 inspired by Wintermaul. Players place towers on a grid to maze enemies, shaping their path from spawn to exit across increasingly difficult waves.

## Features

- **Maze-building TD** — Place towers to create winding paths; invalid placements that block all routes are rejected automatically
- **3 tower types** — Peasant (cheap/fast), Archer (long-range), Catapult (AoE), each with one upgrade tier
- **3 enemy types** — Normal, Fast, and Armored with different speeds, HP, and gold rewards
- **4 handcrafted maps** — Plains, Valley, and Siege with varying spawns, obstacles, and difficulty
- **Procedural maps** — Randomized layouts with difficulty 1-5, seed-based replay, and path-validated obstacle placement
- **Economy** — Earn gold from kills and wave completions; spend on towers and upgrades

## Running

Requires [Godot 4.6](https://godotengine.org/download).

```
godot --path .
```

Or open the project in the Godot editor and press F5.

## Controls

- **Left click** — Place selected tower / open tower menu (upgrade/remove)
- **1 / 2 / 3** — Select tower type (Peasant / Archer / Catapult)
- **Send Wave** button — Start the next wave

## Project Structure

```
scripts/
  game_state.gd          # Autoload singleton for session state
  map_select.gd          # Map selection screen with procedural option
  td_battle/
    td_battle.gd         # Battle orchestrator
    grid_manager.gd      # Grid, AStar pathfinding, tower placement
    wave_manager.gd      # Wave spawning and economy
    map_data.gd          # Data container for map definitions
    map_registry.gd      # Static registry of handcrafted maps
    map_generator.gd     # Procedural map generation
    enemy.gd             # Enemy movement and HP
    tower.gd             # Tower targeting and shooting
scenes/
  main.tscn              # Main menu
  map_select.tscn        # Map selection
  td_battle/
    td_battle.tscn        # Battle scene
```

## License

All rights reserved.
