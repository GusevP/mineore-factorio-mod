# Miner Planner Mod for Factorio 2.0 + Space Age

## Overview

A Factorio 2.0 mod that automates mining drill placement on ore patches, inspired by the P.U.M.P. mod (which does the same for pumpjacks on oil fields). The mod provides a selection tool that lets players drag-select ore patches, then automatically places ghost mining drills in an optimal grid pattern. Three placement modes control the density/spacing: Productivity (maximum coverage, drills overlap mining areas), Normal (standard grid, balanced), and Efficient (sparse placement, minimal drills for full coverage). Supports all base + Space Age miners (burner, electric, big mining drill) and all minable solid resources across all planets.

## Context

- Files involved: New mod from scratch (empty repo)
- Related patterns: P.U.M.P. mod architecture (selection tool + config GUI + ghost placement)
- Dependencies: base >= 2.0, space-age >= 2.0 (optional dependency)
- Target: Factorio 2.0 with Space Age DLC support

## Mod File Structure

```
factorio-miner-mod/
  info.json              - Mod metadata and dependencies
  data.lua               - Prototype definitions (selection tool, shortcuts, custom inputs)
  control.lua            - Main runtime entry point, event registration
  scripts/
    gui.lua              - GUI creation and event handling
    placer.lua           - Core miner placement algorithm
    calculator.lua       - Grid spacing calculations per mode
    resource_scanner.lua - Detects resources and compatible miners in selected area
  prototypes/
    selection-tool.lua   - Selection tool prototype definition
    shortcut.lua         - Shortcut bar button prototype
    style.lua            - Custom GUI styles
  locale/
    en/
      locale.cfg         - English translations
  graphics/
    icons/               - Mod icon and shortcut icons (32x32, 24x24)
  thumbnail.png          - Mod portal thumbnail (144x144)
```

## Development Approach

- Code first, then manual testing in Factorio
- No automated test framework (Factorio mods run inside the game engine, no standard unit test tooling)
- Each task should be loaded into Factorio and manually verified before proceeding
- Use Factorio console commands for debugging (/c game.print(), log())

## Placement Modes Explained

- **Productivity**: Drills placed edge-to-edge with no gaps. Maximum number of drills, maximum ore throughput. Mining areas overlap significantly. For electric mining drill (3x3 body, 5x5 mining area): drills placed every 3 tiles.
- **Normal**: Drills placed so mining areas just touch without significant overlap. Balanced approach. For electric mining drill: drills placed every 5 tiles.
- **Efficient**: Drills placed at maximum spacing where mining areas still provide full ground coverage with minimal overlap. Fewest drills needed. For electric mining drill: drills placed every 5 tiles with offset rows to maximize unique coverage area per drill.

The exact spacing is computed dynamically based on the selected drill's collision_box and mining_area from prototype data, so it automatically works with any drill size including modded drills.

## Implementation Steps

### Task 1: Mod skeleton and metadata

**Files:**

- Create: `info.json`
- Create: `data.lua`
- Create: `control.lua`
- Create: `locale/en/locale.cfg`

- [x] Create info.json with mod name "miner-planner", version "0.1.0", factorio_version "2.0", dependencies ["base >= 2.0", "? space-age >= 2.0"]
- [x] Create minimal data.lua that requires prototype files (empty for now)
- [x] Create minimal control.lua with basic event registration skeleton
- [x] Create locale.cfg with mod name and description strings
- [x] Create placeholder thumbnail.png (can be a simple colored square for now)
- [x] Verify mod loads in Factorio without errors

### Task 2: Selection tool and shortcut button

**Files:**

- Create: `prototypes/selection-tool.lua`
- Create: `prototypes/shortcut.lua`
- Modify: `data.lua`

- [x] Define a selection-tool-prototype in selection-tool.lua that selects entities of type "resource" (solid resources only, not fluids)
- [x] Define alternate selection mode (shift-click) for removing/cancelling placed ghosts
- [x] Define a shortcut prototype for the shortcut bar with a pickaxe-style icon (use base game sprite as placeholder)
- [x] Wire shortcut activation to give player the selection tool item
- [x] Register on_lua_shortcut event in control.lua to handle shortcut click
- [x] Require prototype files from data.lua
- [x] Verify: clicking shortcut gives selection tool, can drag-select over ore patches, event fires
- [x] Remember that the mode was renamed to 'mineore' and for paths need to use `__${mod_name}__` instead of `__base__` so it turn in `__mineore__/...`

### Task 3: Resource scanning and miner detection

**Files:**

- Create: `scripts/resource_scanner.lua`
- Modify: `control.lua`

- [x] On on_player_selected_area event, collect all resource entities in the selected area
- [x] Group resources by type (iron-ore, copper-ore, etc.)
- [x] Query game prototypes to find all mining-drill prototypes and their resource_categories
- [x] Match compatible drills to the selected resource types
- [x] Extract drill dimensions from prototypes: collision_box (physical size), resource_searching_radius (mining area)
- [x] Store scan results (resource positions, compatible drills, drill specs) for use by GUI and placer
- [x] Verify: select an ore patch, confirm correct resource types and compatible drills are detected via console output

### Task 4: Configuration GUI

**Files:**

- Create: `scripts/gui.lua`
- Create: `prototypes/style.lua`
- Modify: `control.lua`
- Modify: `locale/en/locale.cfg`

- [x] After area selection and resource scan, show a configuration frame (player.gui.screen)
- [x] GUI elements: resource type label showing what was selected, drill selector dropdown (populated with compatible drills), placement mode selector (radio buttons: Productivity / Normal / Efficient), direction preference (N/S/E/W for drill output direction), "Place" button, "Cancel" button
- [x] Add "Remember settings" checkbox - when checked, skip GUI on next use and reuse last settings (like P.U.M.P.)
- [x] Store per-player settings in global table
- [x] Handle on_gui_click, on_gui_selection_state_changed events for GUI interaction
- [x] Add GUI styles in style.lua for consistent look
- [x] Add all GUI strings to locale.cfg
- [x] Verify: GUI opens after selection, all controls work, settings persist

### Task 5: Grid calculation engine

**Files:**

- Create: `scripts/calculator.lua`

- [x] Implement function to calculate drill placement grid based on: drill collision_box dimensions, drill resource_searching_radius, placement mode (Productivity/Normal/Efficient), selected area bounds, resource tile positions
- [x] Productivity mode: spacing = drill physical size (drills touching edge-to-edge)
- [x] Normal mode: spacing = mining area diameter (mining areas touching, no overlap)
- [x] Efficient mode: spacing = mining area diameter with staggered/offset rows for maximum unique coverage
- [x] Return list of {position, direction} for each drill to place
- [x] Filter out positions where the drill body would have no resource tiles underneath (skip empty spots)
- [x] Verify: given known drill sizes and a rectangular area, output expected grid positions

### Task 6: Ghost entity placement

**Files:**

- Create: `scripts/placer.lua`
- Modify: `control.lua`

- [x] Take grid positions from calculator and place entity-ghost for each drill position
- [x] Use surface.create_entity with name="entity-ghost", inner_name=selected drill, position, direction, force=player.force
- [x] Before placing each ghost, check surface.can_place_entity to avoid conflicts with existing entities, water, cliffs
- [x] Skip positions that fail placement check and optionally report count of skipped positions
- [x] Handle alt-selection (shift-drag) to remove/cancel ghost drills placed by this mod in selected area
- [x] Add flying-text feedback showing "Placed X miners" or "No valid positions found"
- [x] Verify: select ore patch, configure, press Place - ghost miners appear in correct grid pattern

### Task 7: Module and quality support

**Files:**

- Modify: `scripts/gui.lua`
- Modify: `scripts/placer.lua`
- Modify: `locale/en/locale.cfg`

- [ ] Add module selector to GUI - dropdown showing compatible modules for the selected drill (speed, productivity, efficiency, quality modules)
- [ ] Add module count selector (up to the drill's module_slots count)
- [ ] When placing ghost drills, also set module requests on the ghost entities using insert_plan or module ghost items
- [ ] Add quality selector dropdown if Space Age is active (normal, uncommon, rare, epic, legendary)
- [ ] When quality is selected, pass quality parameter to ghost entity creation
- [ ] Verify: placed ghost drills show correct module requests and quality level

### Task 8: Polish and edge cases

**Files:**

- Modify: various

- [ ] Handle edge case: player selects area with multiple ore types - show GUI with tabs or let user pick which ore to fill
- [ ] Handle undo: register on_pre_ghost_deconstructed or rely on Factorio's native Ctrl+Z for ghost removal
- [ ] Add mod settings (data.lua settings stage): default placement mode, default drill preference, show-gui-always toggle
- [ ] Add shortcut tooltip and proper icon (create simple 32x32 and 64x64 icons)
- [ ] Ensure proper cleanup on player disconnect / mod removal (on_player_removed, on_configuration_changed)
- [ ] Test on different planets: Nauvis (iron, copper, stone, coal, uranium), Vulcanus (tungsten, calcite with big mining drill), Fulgora (scrap), Gleba (if applicable)
- [ ] Verify: mod works correctly across planet surfaces, handles all resource types

### Task 9: Final verification

- [ ] Load mod in Factorio 2.0 with Space Age enabled
- [ ] Test all three placement modes on a large iron ore patch - verify visual difference in density
- [ ] Test with all three drill types (burner, electric, big) on appropriate resources
- [ ] Test on Vulcanus with tungsten ore and big mining drill
- [ ] Test module placement and quality selection
- [ ] Test "remember settings" feature (skip GUI on repeat use)
- [ ] Test alt-selection ghost removal
- [ ] Test with obstacles present (water, cliffs, existing buildings) - verify graceful skipping
- [ ] Verify no Lua errors in log file after full test session

### Task 10: Documentation

- [ ] Write README.md with mod description, features, usage instructions, screenshots placeholders
- [ ] Add changelog.txt with initial version entry
- [ ] Update info.json description field
- [ ] Move this plan to `docs/plans/completed/`
