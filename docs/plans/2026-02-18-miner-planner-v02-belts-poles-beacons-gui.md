# Miner Planner v0.2: Belts, Poles, Beacons, and Icon-Based GUI

## Overview

Major upgrade to the Miner Planner mod adding:

1. Transport belt placement between paired miner rows (two miners face each other outputting to a shared belt line, with underground belts to create space for infrastructure)
2. Electric pole / substation placement in the gaps between miner rows
3. Beacon placement with module support around mining drills
4. Complete GUI overhaul from dropdowns to icon-based selectors (choose-elem-button) following the P.U.M.P. mod pattern
5. Fix ore selection -- the calculation should only consider the selected resource type, and drills should only be placed where that specific ore exists

## Context

- Files involved: `scripts/gui.lua`, `scripts/placer.lua`, `scripts/calculator.lua`, `scripts/resource_scanner.lua`, `control.lua`, `prototypes/style.lua`, `locale/en/locale.cfg`, `settings.lua`
- New files: `scripts/belt_placer.lua`, `scripts/pole_placer.lua`, `scripts/beacon_placer.lua`
- Related patterns: P.U.M.P. mod uses locked `choose-elem-button` elements for entity selection, sprite-buttons for "none" options, and quality dropdowns with rich text icons
- Dependencies: No new external dependencies

## Development Approach

- Code first, then manual testing in Factorio
- No automated test framework (Factorio mods run inside the game engine)
- Each task should be loaded into Factorio and manually verified before proceeding
- Complete each task fully before moving to the next

## Layout Concept

The miner layout follows this pattern (viewed from above, drills output toward center belt):

```
[Drill =>] [Underground belt entrance] ... [Underground belt exit] [<= Drill]
           [Pole/Substation in gap]     [Belt]
[Drill =>] [Underground belt entrance] ... [Underground belt exit] [<= Drill]
```

For belt orientation = North-South (belt runs vertically):

- Left column drills face east, right column drills face west
- A belt line runs vertically between the two columns
- Underground belts connect each drill's output to the center belt
- Underground belts has orientations
- Poles/substations are placed in the space freed by underground belts

The calculator produces paired rows/columns of drills with a center gap for infrastructure.

## Implementation Steps

### Task 1: Redesign calculator for paired miner rows with belt gap

**Files:**

- Modify: `scripts/calculator.lua`

- [x] Refactor `calculate_positions` to produce paired rows/columns of drills facing each other
- [x] Add a `gap` parameter to spacing calculations -- the space between paired rows where belts and infrastructure go
- [x] For each pair, left/right drills get opposite directions (e.g., east and west for vertical belt lines, north and south for horizontal belt lines)
- [x] The gap size depends on: belt type (1 tile for regular belt) + space needed for underground belt connections
- [x] Return positions with individual directions per drill (not uniform direction for all)
- [x] Also return metadata about the belt lines: start/end positions, orientation, and gap center positions for pole/beacon placement
- [x] Ensure drills are only placed where the selected resource type exists (fix the ore filtering issue -- currently `has_resources_in_mining_area` checks all resources, it should check only the selected resource)
- [x] Verify: calculator produces correct paired-row positions with proper directions and gap metadata

### Task 2: Belt placement logic

**Files:**

- Create: `scripts/belt_placer.lua`
- Modify: `scripts/placer.lua`

- [ ] Create belt_placer module that takes calculator output (belt line metadata) and places ghost transport belts
- [ ] Place regular belt segments along the center line between paired drill rows
- [ ] Place underground belt entrances at each drill output position connecting to the center belt line
- [ ] Place underground belt exits at the center belt line receiving from each drill
- [ ] Handle belt direction: belts in the center line all run the same direction (toward a collection point or end of the row)
- [ ] Accept belt type from settings (transport-belt, fast-transport-belt, express-transport-belt, turbo-transport-belt, etc.)
- [ ] Use `surface.can_place_entity` before placing each belt ghost, skip if blocked
- [ ] Integrate belt placement call into the main placer.place() flow after drill placement
- [ ] Verify: ghost belts appear correctly connecting paired drill rows

### Task 3: Pole/substation placement logic

**Files:**

- Create: `scripts/pole_placer.lua`
- Modify: `scripts/placer.lua`

- [ ] Create pole_placer module that places electric poles or substations in the gaps between paired drill rows
- [ ] Use the gap positions from calculator output to determine where poles can go
- [ ] For small poles (1x1): place at intervals based on supply_area_distance to cover all drills
- [ ] For substations (2x2): place at intervals based on supply area, accounting for larger collision box
- [ ] Calculate optimal pole spacing to ensure all drills are within supply range
- [ ] Use wire reach to ensure poles can connect to each other in a chain
- [ ] Read pole prototype data at runtime: supply_area_distance, max_wire_distance, collision_box size
- [ ] Use `surface.can_place_entity` before placing, skip if blocked
- [ ] Integrate pole placement call into placer.place() flow after belt placement
- [ ] Verify: ghost poles appear in gaps, all drills would be powered

### Task 4: Beacon placement logic

**Files:**

- Create: `scripts/beacon_placer.lua`
- Modify: `scripts/placer.lua`

- [ ] Create beacon_placer module that places beacons around the mining drill layout
- [ ] Use a greedy coverage approach (inspired by P.U.M.P.): find positions where a beacon affects the most drills, place there, repeat
- [ ] Respect beacon prototype's supply_area_distance (effect radius) and collision_box
- [ ] Avoid placing beacons where they would collide with drills, belts, or poles already in the plan
- [ ] Maintain a "blocked positions" set that accumulates as drills, belts, poles are placed
- [ ] Support configurable max beacons per drill (from settings)
- [ ] Set beacon module requests on ghost entities using insert_plan (same pattern as drill modules)
- [ ] Accept beacon module type and count from GUI settings
- [ ] Integrate beacon placement into placer.place() flow as the last entity placement step
- [ ] Verify: ghost beacons placed around drill rows, modules set correctly

### Task 5: Rewrite GUI with icon-based selectors

**Files:**

- Modify: `scripts/gui.lua`
- Modify: `prototypes/style.lua`
- Modify: `locale/en/locale.cfg`
- Modify: `control.lua`

- [ ] Replace drill dropdown with a row of locked `choose-elem-button` elements (one per compatible drill), following P.U.M.P. pattern
- [ ] Add belt type selector: row of locked `choose-elem-button` for belt types (transport-belt, fast-transport-belt, etc.) plus a "none" sprite-button to skip belt placement
- [ ] Add underground belt selector: automatically paired with the selected belt type (or let user override)
- [ ] Add pole/substation selector: row of locked `choose-elem-button` for electric poles and substations plus a "none" sprite-button
- [ ] Add beacon selector: row of locked `choose-elem-button` for beacon types plus a "none" sprite-button
- [ ] Add beacon module selector: a single unlocked `choose-elem-button` (elem_type="item", filtered to modules compatible with the selected beacon)
- [ ] Rework drill module selector from dropdown to unlocked `choose-elem-button`
- [ ] Add quality dropdowns per entity row using rich text quality icons (e.g., `[quality=normal]`), following P.U.M.P. pattern
- [ ] Update `gui.read_settings()` to read all new selectors (belt, pole, beacon, beacon module, quality per entity type)
- [ ] Handle `on_gui_click` for locked choose-elem-buttons (toggle pressed/unpressed style to show selection)
- [ ] Handle `on_gui_elem_changed` for unlocked module choose-elem-buttons
- [ ] Remove old dropdown-based resource selector -- resources are shown as info only; the single selected resource flows from the scan
- [ ] Keep placement mode radio buttons (Productivity/Normal/Efficient)
- [ ] Remove direction selector -- direction is now implicit (drills always face the center belt line)
- [ ] Add belt orientation selector: radio buttons for belt running North-South vs East-West
- [ ] Update all locale strings for new GUI elements
- [ ] Verify: GUI shows icon buttons for all entity types, selections work correctly

### Task 6: Wire up new GUI settings to placer pipeline

**Files:**

- Modify: `scripts/placer.lua`
- Modify: `control.lua`

- [ ] Update placer.place() to accept and pass through new settings: belt_name, underground_belt_name, pole_name, beacon_name, beacon_module_name, belt_quality, pole_quality, beacon_quality
- [ ] Orchestrate placement order: drills first, then belts, then poles, then beacons
- [ ] Accumulate blocked positions through the pipeline so later placements don't collide with earlier ones
- [ ] Update control.lua GUI event handlers for new element types (on_gui_click for choose-elem-buttons, on_gui_elem_changed for module pickers)
- [ ] Update "remember settings" to include all new settings
- [ ] Update alt-selection (shift-drag) to also remove ghost belts, poles, and beacons placed in the selection area
- [ ] Update flying text feedback to include counts for each entity type placed
- [ ] Verify: full pipeline works end-to-end -- select ore, configure in GUI, place all entity types

### Task 7: Add mod settings for beacons

**Files:**

- Modify: `settings.lua`
- Modify: `locale/en/locale.cfg`

- [ ] Add runtime setting: "mineore-max-beacons-per-drill" (int, default 4, min 1, max 12)
- [ ] Add runtime setting: "mineore-preferred-beacons-per-drill" (int, default 1, min 0, max 12)
- [ ] Add locale strings for new settings
- [ ] Read these settings in beacon_placer module
- [ ] Verify: settings appear in mod settings menu and affect beacon placement

### Task 8: Final verification and polish

- [ ] Test the full workflow: select ore, GUI shows icon buttons, select belt/pole/beacon, place all ghosts
- [ ] Test with "none" selected for belts -- drills should still place without belts
- [ ] Test with "none" selected for poles and beacons -- should work like current mod
- [ ] Test all three placement modes with the new paired-row layout
- [ ] Test on different planet surfaces (Nauvis, Vulcanus, Fulgora)
- [ ] Test with different belt tiers, pole types, and beacon types
- [ ] Test beacon module assignment (speed modules, productivity modules)
- [ ] Test quality selection per entity type
- [ ] Test "remember settings" with all new options
- [ ] Test alt-selection removes all entity types (drills, belts, poles, beacons)
- [ ] Verify no Lua errors in log file
- [ ] Update README.md with new features
- [ ] Update changelog.txt
- [ ] Update info.json version to 0.2.0
