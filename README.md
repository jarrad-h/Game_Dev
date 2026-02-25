# Hex Strategy

A turn-based hex-grid strategy game built in Godot 4 with GDScript.

## Game Overview

Form battle lines, build your economy, and crush your opponent through superior logistics. Features Supreme Commander-style automated transport routes from factories to the front line.

### Core Mechanics

- **Hex Grid Combat**: Units form battle lines with adjacency bonuses. Flanking punishes exposed units. Zone of control creates meaningful frontlines.
- **Automated Logistics**: Set factory rally points, define transport routes, and let units flow to the front automatically.
- **Economy & Production**: Build extractors (materials) and power plants (energy). Factories queue unit production.
- **Technology**: Research unlocks new units (armor, artillery), buildings (supply depots), and upgrades.
- **AI Opponent**: Priority-based AI that builds economy, researches tech, produces units, and attacks.

### Units

| Unit | HP | ATK | DEF | Move | Range | Cost |
|------|-----|-----|-----|------|-------|------|
| Infantry | 100 | 15 | 10 | 2 | 1 | 20 mat, 5 eng |
| Armor | 200 | 30 | 20 | 3 | 1 | 60 mat, 20 eng |
| Artillery | 60 | 40 | 5 | 1 | 3 | 50 mat, 15 eng |

### Buildings

- **Headquarters**: Starting base. Produces basic resources and units.
- **Factory**: Main unit production building with 2 production slots.
- **Resource Extractor**: Generates +10 materials/turn.
- **Power Plant**: Generates +10 energy/turn.
- **Supply Depot**: Logistics waypoint that boosts transport route capacity.

## How to Play

1. Open the project in **Godot 4.2+**
2. Press F5 (or Play) to run
3. **Click units** to select and move them
4. **Click enemies** adjacent to selected unit to attack
5. **Build button** (top bar) opens building placement
6. **Tech button** (top bar) opens technology research
7. **Click a factory** to queue unit production, set rally points, or create transport routes
8. **End Turn** button advances the game

### Controls

- **WASD / Arrow keys**: Pan camera
- **Mouse wheel**: Zoom in/out
- **Middle mouse drag**: Pan camera
- **Left click**: Select / interact
- **Right click**: Cancel current action

## Architecture

The game uses a modular, data-driven architecture:

- `data/*.json` — All game content (units, buildings, terrain, resources, tech). Add new content by editing JSON files only.
- `scripts/autoload/` — Singletons: GameData (JSON loader), GameState (global state), EventBus (signal bus), Constants.
- `scripts/hex/` — Hex math, grid data structure, A* pathfinding.
- `scripts/systems/` — Independent game systems (turn, combat, production, logistics, tech, fog of war).
- `scripts/entities/` — Unit and building logic with procedural `_draw()` rendering.
- `scripts/ai/` — AI controller with economy and military sub-modules.
- `scripts/ui/` — HUD and camera controller.

### Adding New Content

**New unit type**: Add an entry to `data/units.json`. No code changes needed — the factory and UI automatically pick it up.

**New building**: Add to `data/buildings.json`. If it needs special behavior, extend `building.gd`.

**New technology**: Add to `data/tech_tree.json` with prerequisites and unlock references.

**New terrain**: Add to `data/terrain.json` with movement cost and defense bonus.
