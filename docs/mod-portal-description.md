Miner Planner automates mining drill placement on ore patches. Drag-select an area, pick your drill, belts, poles, and beacons from an icon-based GUI, and ghost entities are placed in optimized paired-row layouts ready for construction bots. Works with all drill types, belt tiers, pole types, and resources across all planets.

---

## Placement Modes

### Productivity
Maximum drills, edge-to-edge, highest ore throughput.

![Productivity mode](https://github.com/GusevP/mineore-factorio-mod/blob/main/docs/images/base_prod.gif?raw=true)

### Efficient
Fewest drills, staggered rows for maximum coverage per drill.

![Efficient mode](https://github.com/GusevP/mineore-factorio-mod/blob/main/docs/images/base_efficient.gif?raw=true)

---

## Features

- **Drag-select placement** — select any ore patch and ghost miners appear in an optimal grid
- **Two placement modes** — *Productivity* (maximum drills, edge-to-edge) or *Efficient* (fewest drills, staggered rows)
- **Full entity selection** — choose drill type, transport belt tier, electric pole type, beacon type, and quality for each
- **Beacon support** — beacons fill alongside drill rows with configurable max and preferred counts per drill; includes beacon module selection
- **Underground belts** — automatically placed for 3×3+ drills to keep belt runs clean
- **4-direction belt flow** — north, south, east, or west
- **Pipe placement** — automatic pipes for fluid-requiring resources (e.g. uranium ore with sulfuric acid), with pipe type and quality selection
- **Polite placement mode** — only clears trees and rocks, preserving existing buildings
- **Drill modules** — select modules to insert into placed drill ghosts
- **Ore-type filtering** — drills skip positions where the mining area overlaps a different ore type
- **Obstacle clearing** — trees, rocks, and cliffs in the placement zone are marked for deconstruction
- **Ghost cleanup** — shift-drag to remove placed ghost miners, belts, poles, pipes, and beacons
- **Remember settings** — skip the GUI on repeat placements and reuse your last configuration
- **Multi-planet support** — works with any resource on any surface (Nauvis, Vulcanus, Fulgora, Gleba, Aquilo)

---

## How to Use

1. Click the Miner Planner shortcut button in the toolbar (or press ALT+M)
2. Drag-select an ore patch
3. In the configuration GUI, choose your drill, belt, pole, beacon, and placement mode
4. Click "Place Miners" — ghost entities are placed for bots to build
5. Shift-drag over an area to remove previously placed ghosts

---

## Mod Settings

All settings are per-player:

- **Default placement mode** — choose Productivity or Efficient as the default when opening the GUI
- **Always show configuration GUI** — when disabled, uses remembered settings to skip the GUI
- **Max beacons per drill** — upper limit on how many beacons can affect a single drill (1–12, default 4)
- **Preferred beacons per drill** — target beacon count; placement stops once each drill reaches this number (0 = no limit, default 1)

---

## Requirements

- Factorio 2.0+
- Optional: Space Age expansion (for multi-planet resources)

---

## Credits

Inspired by the P.U.M.P. mod. Built to make large-scale mining setups fast and painless.
