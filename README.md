# Miner Planner

A Factorio 2.0 mod that automates mining drill placement on ore patches with transport belts, electric poles, and beacons. Select an area over any ore patch, configure your layout via an icon-based GUI, and the mod places ghost entities in paired-row layouts — ready for bots to build.

Inspired by the [P.U.M.P. mod](https://mods.factorio.com/mod/pump) which does the same for pumpjacks on oil fields.

## Features

- **Selection tool** — drag-select any ore patch to start planning miners
- **Paired-row drill layout** — drills face each other with a belt gap between them for efficient output collection
- **Two placement modes:**
  - **Productivity** — maximum drills, edge-to-edge, highest ore throughput
  - **Efficient** — fewest drills, staggered rows for maximum coverage per drill
- **Transport belt placement** — belts placed in the gap between paired drill rows; underground belts used for 3x3+ drills
- **Electric pole placement** — 1x1 poles placed at optimal intervals for full power coverage
- **Beacon placement** — beacons placed between drill pair columns/rows, shared across adjacent pairs, with configurable limits per drill
- **All drill types** — burner, electric, and big mining drills
- **All belt tiers** — transport belt, fast, express, turbo, and any modded belts
- **1x1 electric poles** — small and medium electric poles (substations and big poles excluded due to size constraints)
- **All resources** — works with every solid minable resource across all planets (Nauvis, Vulcanus, Fulgora, Gleba)
- **Icon-based GUI** — choose-elem-button selectors for all entity types (following P.U.M.P. pattern)
- **Module support** — pre-request modules on ghost drills and beacons (speed, productivity, efficiency, quality)
- **Quality support** — per-entity quality selection for drills, belts, poles, and beacons (Space Age)
- **Belt direction** — choose North, South, East, or West belt flow direction
- **Remember settings** — skip the GUI on repeat use by remembering your last configuration
- **Pipe placement** — automatic pipe connections between drills when mining fluid-requiring resources (e.g., uranium ore with sulfuric acid)
- **Polite placement mode** — optional mode that only clears trees and rocks, skipping positions blocked by existing buildings or other entities
- **Ghost removal** — shift-drag to remove ghost miners, belts, poles, and beacons in an area
- **Obstacle handling** — trees, rocks, and cliffs are marked for deconstruction; conflicting entities are demolished to allow ghost placement

## Requirements

- Factorio 2.0
- Space Age DLC (optional, enables quality selection and big mining drill support)

## Installation

1. Download from the [Factorio Mod Portal](https://mods.factorio.com/) or place the mod folder in your Factorio mods directory
2. Enable "Miner Planner" in the mod settings

## Usage

1. Click the Miner Planner shortcut button in the shortcut bar (or use the keybind)
2. Drag-select over an ore patch
3. In the configuration GUI:
   - Select which resource to place miners on (if multiple ore types were selected)
   - Choose a mining drill by clicking its icon
   - Choose a transport belt type (or "none" to skip belts)
   - Choose an electric pole type (or "none" to skip poles)
   - Choose a beacon type (or "none" to skip beacons) and select a module for beacons
   - Choose a pipe type when mining fluid-requiring resources like uranium ore (or "none" to skip pipes)
   - Pick a placement mode (Productivity / Efficient)
   - Set belt direction (North / South / East / West)
   - Optionally enable "Polite placement" to preserve existing buildings
   - Optionally select drill modules and quality levels per entity type
   - Check "Remember settings" to skip this dialog next time
4. Click "Place Miners" — ghost entities appear in the selected area
5. Your construction bots will build them automatically

To remove placed ghost entities, hold Shift and drag-select over the area.

## Mod Settings

- **Default placement mode** — choose which mode is selected by default (Productivity or Efficient)
- **Always show configuration GUI** — when disabled, uses remembered settings if available
- **Max beacons per drill** — maximum number of beacons that can affect any single drill (1-12, default 4)
- **Preferred beacons per drill** — target number of beacons per drill; placement stops once each drill reaches this count (0-12, default 1; 0 = no limit)

## License

MIT
