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
[ ] Manual test: load in Factorio with burner mining drills (2x2) - should
see plain belts
[ ] Manual test: load with electric mining drills (3x3) - should see
UBO/UBI/Pole pattern
[ ] Manual test: verify belt flow direction is correct and items transport
properly

### Task 2: Polish electric pole / substation placement

Currently pole_placer.lua only handles 1x1 poles. Add support for larger
poles like substations (2x2) and big electric poles.

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
[ ] Manual test: place with small wooden pole (1x1) - should work as before
[ ] Manual test: place with medium electric pole (1x1) - should work as
before
[ ] Manual test: place with substation (2x2) - should place in freed rows
between drill groups

### Task 3: Adjust beacon placement logic

Align beacon placement with the layout concept patterns. Beacons should fill
the outer columns/rows alongside drill pairs.

Files:

• Modify: scripts/beacon_placer.lua
• Modify: scripts/calculator.lua (if beacon candidate generation needs
more drill layout info)
[ ] For 3x3 drills with 3x3 beacons: one beacon column on each side, beacon
y-positions align with drill rows (Pattern 3)
[ ] For bigger drills (5x5+): fill beacon columns with as many beacons as
fit along the drill column length (e.g., 2-3 beacons per 5x5 drill)
[ ] Ensure beacons don't overlap with each other or with drills/belts
[ ] Verify the greedy algorithm still respects max-beacons-per-drill and
preferred-beacons-per-drill settings
[ ] Manual test: 3x3 drills with beacons enabled - beacons should form clean
columns on both sides
[ ] Manual test: verify beacon supply areas cover the drills they're meant
to boost

### Task 4: Fix drill placement to respect ore selection

When the user selects a specific ore type, drills whose mining area would
cover tiles of a different ore should not be placed.

Files:

• Modify: scripts/calculator.lua (the has_resources_in_mining_area
function and position filtering)
• Possibly modify: scripts/resource_scanner.lua (if multi-ore data needs
enrichment)
[ ] When a specific ore is selected (not "all"), check each candidate drill
position's full mining area
[ ] If the mining area contains any tiles of a different ore type, skip that
drill position
[ ] Build a resource tile set per ore type from the scan data to enable this
check
[ ] Keep existing behavior when "all" ores are selected (place drill if any
resource overlaps)
[ ] Manual test: select iron ore on a patch bordering copper - drills near
the boundary should not be placed if their mining area overlaps copper
[ ] Manual test: select "all" - should place drills as before with no
filtering

### Task 5: Demolish obstacles in the planned placement zone

The mod should mark trees, rocks, cliffs, and buildings in the placement
zone for deconstruction before placing ghosts.

Files:

• Modify: scripts/placer.lua (add demolition step before ghost placement)
[ ] After calculating all positions (drills + belts + poles + beacons),
compute the full bounding box of the placement zone
[ ] Find all entities in that zone that would block placement: trees,
rocks/stones, cliffs, and player buildings
[ ] For each blocking entity, order deconstruction ( entity.
order_deconstruction() ) so construction bots will clear them
[ ] Run demolition before ghost placement so can_place_entity checks are
more accurate
[ ] Do NOT demolish resource entities (ores) or other ghost entities
[ ] Manual test: place miners in an area with trees - trees should get
marked for deconstruction
[ ] Manual test: ensure ores and existing ghost entities are not affected

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
[ ] In gui.lua, replace the NS/EW radio buttons with 4 icon buttons using
Factorio's built-in arrow sprites (e.g., utility/indication_arrow )
[ ] Store selected direction as one of: "north" , "south" , "east" ,
"west" in settings
[ ] Map directions to belt flow: North = belt flows up, South = belt flows
down, West = belt flows left, East = belt flows right
[ ] N and S share the same drill column layout (vertical pairs) but with
opposite belt directions; same for W and E (horizontal pairs)
[ ] Update calculator to flip drill facing directions based on selected
direction (e.g., South: left drills face east, right face west; North: left
drills face west, right face east)
[ ] Update belt_placer to set belt direction matching the selected direction
[ ] Update pole_placer and beacon_placer to use the correct axis based on
direction
[ ] Maintain backward compatibility: existing saved settings with "NS"/"EW"
should map to "south"/"east" respectively
[ ] Manual test: place miners in each of the 4 directions and verify belt
flow, drill facing, and pole/beacon positions are correct
[ ] Manual test: verify the GUI shows 4 arrow buttons and highlights the
selected one

### Task 7: Rename "Normal" mode to "Loose" and adjust spacing

Files:

• Modify: scripts/calculator.lua (rename mode, adjust spacing formula)
• Modify: scripts/gui.lua (update label)
• Modify: locale/en/locale.cfg (update string)
• Modify: settings.lua (update allowed values)
[ ] Rename the "normal" mode to "loose" in all code references
[ ] Adjust the Loose spacing formula: next drill is placed mining_radius
tiles from the previous drill (respecting only one drill's mining zone, not
both). Currently spacing = mining_diameter , change to spacing = body_size +
mining_radius where mining_radius = floor(radius)
[ ] Update the "efficient" mode description: spacing stays mining_diameter
(respects both drills' zones) with row offset
[ ] Update GUI label and locale string
[ ] Update settings.lua allowed_values from "normal" to "loose"
[ ] Handle migration: if a player had "normal" saved, treat it as "loose"
[ ] Manual test: compare drill spacing in all 3 modes side by side

### Task 8: Version bump and final verification

Files:

• Modify: info.json (bump version to 0.3.0)
[ ] Bump version to 0.3.0 in info.json
[ ] Verify all 6 features work together in combination
[ ] Test with different drill sizes (2x2 burner, 3x3 electric)
[ ] Test with and without beacons
[ ] Test with different pole types
[ ] Test all 4 directions
