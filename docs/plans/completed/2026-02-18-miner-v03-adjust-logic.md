Miner Planner v0.3: Belts, Poles, Beacons

## Overview

Major upgrade to the Miner Planner mod covering 6 areas: underground belt
placement between miner rows, improved pole/substation support, beacon
placement adjustments, drill ore-filtering, demolition of obstacles in the
placement zone, and 4-direction support in the GUI.

## Context

• Files involved:
• scripts/calculator.lua - drill position math, spacing, belt line
metadata
• scripts/placer.lua - orchestration pipeline for ghost placement
• scripts/belt_placer.lua - belt ghost placement in the inter-row gap
• scripts/pole_placer.lua - electric pole placement at intervals
• scripts/beacon_placer.lua - greedy beacon placement on outer edges
• scripts/gui.lua - full configuration GUI
• scripts/resource_scanner.lua - ore detection and drill compatibility
• control.lua - event handlers and flow orchestration
• locale/en/locale.cfg - UI strings
• info.json - version bump
• Related patterns: ghost entity placement via surface.create_entity ,
prototype reading at runtime, icon-button GUI selectors
• Dependencies: none external

## Development Approach

• Code first, then manual testing in Factorio
• Wait to approve by manual testing to move to the next step/iteration
• No automated test framework (Factorio mods run inside the game engine)
• Each task should be loaded into Factorio and manually verified before
proceeding
• Complete each task fully before moving to the next

## Implementation Steps

### Task 1: Refactor transport belt placement to use underground belts

Currently belt_placer.lua places only plain transport belts in the 2-tile
gap. Refactor to follow the layout concept patterns from the plan doc.

Files:

• Modify: scripts/belt_placer.lua
• Modify: scripts/calculator.lua (belt_lines metadata may need underground
belt info)
[x] For 2x2 drills (burner mining drill): keep plain belt placement as-is
(Pattern 1 from layout concept)
[x] For 3x3+ drills: place underground belt entrance (UBI) on the row
nearest drill output, underground belt exit (UBO) on the row before it, and
pole slot on remaining row
[x] The UBI/UBO placement logic should respect drill body size - UBI aligns
with drill output (center of drill), UBO is placed before it in belt flow
direction
[x] Underground belts should use the same belt type/quality selected by the
user (transport-belt -> underground-belt naming convention)
[x] For bigger drills (5x5+), apply Pattern 4: UBI near drill center output,
UBO before it, fill remaining gap rows with plain belt
[x] Ensure belt direction matches orientation (south for NS, east for EW)
[x] Update calculator to provide enough metadata (drill size, output
position) for belt_placer to choose the right pattern
[x] Fix the drill placement logic. Change the gap to 1 in belt_placer and never use two-gap/belt system. Belts should be plain only for 2x2 drills. For all other there should be underground belts. There is still 2 lines of plain belts instead of 1 line of underground. Follow this concept:
Symbols for patterns:

```
B - Belt
UB - Underground Belt
UBI - Underground Belt Entrance
UBO - Underground Belt Exit
```

The miner productive layout follows this patterns (viewed from above, drills output toward center belt), the direction is South (to the bottom), the gap is always 1. Underground belts should use the same type as belt type selected in GUI:

1. Starter,cheap variant - only for 2x2 drills (Burner mining drill), without beacons. Actually beacons haven't been available there yet.

```
[1L.Drill =>] [Belt] [<= 1R.Drill]
[1L.Drill =>] [Belt] [<= 1R.Drill]
[2L.Drill =>] [Belt] [<= 2R.Drill]
[2L.Drill =>] [Belt] [<= 2R.Drill]
       [Pole] [Belt] [Pole]
[3L.Drill =>] [Belt] [<= 3R.Drill]
[3L.Drill =>] [Belt] [<= 3R.Drill]
[4L.Drill =>] [Belt] [<= 4R.Drill]
[4L.Drill =>] [Belt] [<= 4R.Drill]
```

2. Most-used variant for electric 3x3 drills, without beacon.

```
[1L.Drill =>] [UBO]  [<= 1R.Drill]
[1L.Drill =>] [UBI]  [<= 1R.Drill]
[1L.Drill =>] [Pole] [<= 1R.Drill]
[2L.Drill =>] [UBO]  [<= 2R.Drill]
[2L.Drill =>] [UBI]  [<= 2R.Drill]
[2L.Drill =>] [Pole] [<= 2R.Drill]
[3L.Drill =>] [UBO]  [<= 3R.Drill]
[3L.Drill =>] [UBI]  [<= 3R.Drill]
[3L.Drill =>] [Pole] [<= 3R.Drill]
```

3. Most-used variant for electric 3x3 drills, with beacons.

```
[1L.Beacon][1L.Drill =>] [UBO]  [<= 1R.Drill][1R.Beacon]
[1L.Beacon][1L.Drill =>] [UBI]  [<= 1R.Drill][1R.Beacon]
[1L.Beacon][1L.Drill =>] [Pole] [<= 1R.Drill][1R.Beacon]
[2L.Beacon][2L.Drill =>] [UBO]  [<= 2R.Drill][2R.Beacon]
[2L.Beacon][2L.Drill =>] [UBI]  [<= 2R.Drill][2R.Beacon]
[2L.Beacon][2L.Drill =>] [Pole] [<= 2R.Drill][2R.Beacon]
[3L.Beacon][3L.Drill =>] [UBO]  [<= 3R.Drill][3R.Beacon]
[3L.Beacon][3L.Drill =>] [UBI]  [<= 3R.Drill][3R.Beacon]
[3L.Beacon][3L.Drill =>] [Pole] [<= 3R.Drill][3R.Beacon]
```

4. For bigger drills we should use the previous pattern #2 Most-used variant. But the [UBI] should be near the drill output (usually the center) and the [UBO] is before the [UBI]. The beacons have the same logic, but the size of beacons could be different with size of drills, so just place as much beacons as we can to fill the length of drill columns. For example for 5x5 drills: The size of beacon is usually 3x3. So we can place 2-3 beacons for one 5x5 drill. Or 4-5 beacons for two 5x5 drills.

5. Effective mod should respect the zone of mining of each drill. It's just about the free space between drills, nothing more. It should respect described patterns.

6. Third normal mode should be renamed to 'Loose'. I imagine it as something between productive and effective modes. Like next drill should respect the zone of other drill, but not it's own. Fo example drill is 3x3 size and the full zone coverage is 5x5. So the productive mode will place drills next to each other. Effective mode place the next drill in 4 tiles from previous drill. 2 tiles for one drill and 2 tiles for second. `(5 - 3 = 2; 2 * 2 = 4)`. Loose mode just place the next drill in 2 tiles from previous. Like it respect the mining zone of one drill, not both.

For belt orientation = North-South (belt runs vertically):

- Left column drills face east, right column drills face west
- A belt line runs vertically between the two columns of drills
- Underground belts connect each drill's output to the center belt
- Underground belts has orientations
- Poles are placed in the space freed by underground belts

The calculator produces paired rows/columns of drills with a center gap for infrastructure.

[x] Manual test: load in Factorio with burner mining drills (2x2) - should
see plain belts
[x] Manual test: load with electric mining drills (3x3) - should see
UBO/UBI/Pole pattern
[x] Manual test: verify belt flow direction is correct and items transport
properly

### Task 2: Polish electric pole / substation placement

Currently pole_placer.lua only handles 1x1 poles.

Files:

• Modify: scripts/pole_placer.lua
[x] Read pole prototype width/height at runtime (already reads
supply_area_distance and max_wire_distance)
[x] For poles wider than 1 tile, calculate placement positions accounting
for the pole occupying multiple tiles in the gap
[x] If the pole is too wide to fit in the 2-tile gap between drill pairs,
place it in the free rows between drill groups (the rows freed up by
underground belts - the "Pole" slot in layout patterns)
[x] Adjust spacing calculation to account for larger supply areas of
substations
[x] Handle the case where a substation is selected but gap is too narrow -
fall back to placing in the pole-slot rows only
[x] Ensure poles don't collide with drills, belts, or underground belts
[x] Remove support for larger poles like substations (2x2) and big electric poles
[x] Manual test: place with small wooden pole (1x1) - should work as before
[x] Manual test: place with medium electric pole (1x1) - should work as
before
[x] Manual test: place with substation (2x2) - should place in freed rows
between drill groups

### Task 3: Adjust beacon placement logic

Align beacon placement with the layout concept patterns. Beacons should fill
the outer columns/rows alongside drill pairs.

Files:

• Modify: scripts/beacon_placer.lua
• Modify: scripts/calculator.lua (if beacon candidate generation needs
more drill layout info)
[x] For 3x3 drills with 3x3 beacons: one beacon column on each side, beacon
y-positions align with drill rows (Pattern 3)
[x] For bigger drills (5x5+): fill beacon columns with as many beacons as
fit along the drill column length (e.g., 2-3 beacons per 5x5 drill)
[x] Fix the beacon placement as they don't fill the all available space in a column/row bu the have to fill it.
[x] Ensure beacons don't overlap with each other or with drills/belts
[x] Verify the greedy algorithm still respects max-beacons-per-drill and
preferred-beacons-per-drill settings
[x] Manual test: 3x3 drills with beacons enabled - beacons should form clean
columns on both sides
[x] Manual test: verify beacon supply areas cover the drills they're meant
to boost

### Task 4: Fix drill placement to respect ore selection

When the user selects a specific ore type, drills whose mining area would
cover tiles of a different ore should not be placed.

Files:

• Modify: scripts/calculator.lua (the has_resources_in_mining_area
function and position filtering)
• Possibly modify: scripts/resource_scanner.lua (if multi-ore data needs
enrichment)
[x] When a specific ore is selected (not "all"), check each candidate drill
position's full mining area
[x] If the mining area contains any tiles of a different ore type, skip that
drill position
[x] Build a resource tile set per ore type from the scan data to enable this
check
[x] Keep existing behavior when "all" ores are selected (place drill if any
resource overlaps)
[x] Skip placing drill if it size with zone overlap wrong ore.
[x] Manual test: select iron ore on a patch bordering copper - drills near
the boundary should not be placed if their mining area overlaps copper
[x] Manual test: select "all" - should place drills as before with no
filtering

### Task 5: Demolish obstacles in the planned placement zone

The mod should mark trees, rocks, cliffs, and buildings in the placement
zone for deconstruction before placing ghosts.

Files:

• Modify: scripts/placer.lua (add demolition step before ghost placement)
[x] After calculating all positions (drills + belts + poles + beacons),
compute the full bounding box of the placement zone
[x] Find all entities in that zone that would block placement: trees,
rocks/stones, cliffs, and player buildings
[x] For each blocking entity, order deconstruction ( entity.
order_deconstruction() ) so construction bots will clear them
[x] Run demolition before ghost placement so can_place_entity checks are
more accurate
[x] Do NOT demolish resource entities (ores) or other ghost entities
[x] Manual test: place miners in an area with trees - trees should get
marked for deconstruction
[x] Manual test: ensure ores and existing ghost entities are not affected

### Task 6: Add support for 4 directions (N, S, W, E)

Replace the current NS/EW radio buttons with a 4-direction selector using
arrow icons. Each direction controls where belts flow to.

Files:

• Modify: scripts/gui.lua (replace orientation radio buttons with
direction icon buttons)
• Modify: scripts/calculator.lua (handle 4 directions for drill facing and
belt flow)
• Modify: scripts/belt_placer.lua (belt direction based on N/S/W/E)
• Modify: scripts/pole_placer.lua (pole axis based on direction)
• Modify: scripts/beacon_placer.lua (beacon column/row axis based on
direction)
• Modify: scripts/placer.lua (pass direction through pipeline)
• Modify: locale/en/locale.cfg (new tooltip strings for direction buttons)
[x] In gui.lua, replace the NS/EW radio buttons with 4 icon buttons using
Factorio's built-in arrow sprites (e.g., utility/indication_arrow )
[x] Store selected direction as one of: "north" , "south" , "east" ,
"west" in settings
[x] Map directions to belt flow: North = belt flows up, South = belt flows
down, West = belt flows left, East = belt flows right
[x] N and S share the same drill column layout (vertical pairs) but with
opposite belt directions; same for W and E (horizontal pairs)
[x] Update calculator to flip drill facing directions based on selected
direction (e.g., South: left drills face east, right face west; North: left
drills face west, right face east)
[x] Update belt_placer to set belt direction matching the selected direction
[x] Update pole_placer and beacon_placer to use the correct axis based on
direction
[x] Maintain backward compatibility: existing saved settings with "NS"/"EW"
should map to "south"/"east" respectively
[x] Manual test: place miners in each of the 4 directions and verify belt
flow, drill facing, and pole/beacon positions are correct
[x] Manual test: verify the GUI shows 4 arrow buttons and highlights the
selected one

### Task 7: Rename "Normal" mode to "Loose" and adjust spacing

Files:

• Modify: scripts/calculator.lua (rename mode, adjust spacing formula)
• Modify: scripts/gui.lua (update label)
• Modify: locale/en/locale.cfg (update string)
• Modify: settings.lua (update allowed values)
[x] Rename the "normal" mode to "loose" in all code references
[x] Adjust the Loose spacing formula: next drill is placed mining_radius
tiles from the previous drill (respecting only one drill's mining zone, not
both). Currently spacing = mining_diameter , change to spacing = body_size +
mining_radius where mining_radius = floor(radius)
[x] Update the "efficient" mode description: spacing stays mining_diameter
(respects both drills' zones) with row offset
[x] Update GUI label and locale string
[x] Update settings.lua allowed_values from "normal" to "loose"
[x] Handle migration: if a player had "normal" saved, treat it as "loose"
[x] Manual test: compare drill spacing in all 3 modes side by side

### Task 8: Version bump and final verification

Files:

• Modify: info.json (bump version to 0.3.0)
[x] Bump version to 0.3.0 in info.json
[x] Verify all 6 features work together in combination
[x] Test with different drill sizes (2x2 burner, 3x3 electric)
[x] Test with and without beacons
[x] Test with different pole types
[x] Test all 4 directions
