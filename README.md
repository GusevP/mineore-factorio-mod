# Miner Planner

A Factorio 2.0 mod that automates mining drill placement on ore patches. Select an area over any ore patch, pick your drill and placement mode, and the mod places ghost miners in an optimal grid pattern — ready for bots to build.

Inspired by the [P.U.M.P. mod](https://mods.factorio.com/mod/pump) which does the same for pumpjacks on oil fields.

## Features

- **Selection tool** — drag-select any ore patch to start planning miners
- **Three placement modes:**
  - **Productivity** — maximum drills, edge-to-edge, highest ore throughput
  - **Normal** — balanced spacing, mining areas touch without overlap
  - **Efficient** — fewest drills, staggered rows for maximum coverage per drill
- **All drill types** — burner, electric, and big mining drills
- **All resources** — works with every solid minable resource across all planets (Nauvis, Vulcanus, Fulgora, Gleba)
- **Module support** — pre-request modules (speed, productivity, efficiency, quality) on placed ghost drills
- **Quality support** — select quality level for ghost drills when Space Age is active
- **Output direction** — choose which direction (N/S/E/W) drills face for belt alignment
- **Remember settings** — skip the GUI on repeat use by remembering your last configuration
- **Ghost removal** — shift-drag to remove ghost miners in an area
- **Obstacle handling** — automatically skips positions blocked by water, cliffs, or existing buildings

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
   - Choose a mining drill from the dropdown
   - Pick a placement mode (Productivity / Normal / Efficient)
   - Set the output direction for the drills
   - Optionally select modules and quality level
   - Check "Remember settings" to skip this dialog next time
4. Click "Place Miners" — ghost entities appear in the selected area
5. Your construction bots will build them automatically

To remove placed ghost miners, hold Shift and drag-select over the area.

## Mod Settings

- **Default placement mode** — choose which mode is selected by default (Productivity, Normal, or Efficient)
- **Always show configuration GUI** — when disabled, uses remembered settings if available

## License

MIT
