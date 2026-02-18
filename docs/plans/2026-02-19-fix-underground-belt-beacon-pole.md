# Fix Underground Belt Rotation, Beacon Fill, and Pole Restrictions

## Overview

Fix three bugs in the miner planner placement pipeline:
1. Underground belt output (UBO) faces wrong direction - must be rotated 180 degrees from input
2. Beacons don't fill the full column/row - greedy algorithm stops too early due to max_beacons_per_drill limit
3. Filter pole selector to only show 1x1 poles; remove substations and 2x2 poles from GUI

## Context

- Files involved:
  - `scripts/belt_placer.lua` - underground belt direction assignment
  - `scripts/beacon_placer.lua` - greedy beacon placement algorithm
  - `scripts/pole_placer.lua` - pole placement logic
  - `scripts/gui.lua` - pole selector filtering
- Related patterns: ghost entity placement via surface.create_entity, Factorio underground belt direction semantics
- Dependencies: none external

## Development Approach

- Code first, then manual testing in Factorio
- No automated test framework (Factorio mods run inside the game engine)
- Each task should be loaded into Factorio and manually verified before proceeding
- Complete each task fully before moving to the next

## Implementation Steps

### Task 1: Fix underground belt output direction (rotate UBO 180 degrees)

**Files:**
- Modify: `scripts/belt_placer.lua`

- [x] Add a helper function or lookup table to compute the opposite direction (north<->south, east<->west)
- [x] In `_place_underground_belts`, set `ubo_dir` to the opposite of `belt_dir_define` (the output must face 180 degrees from the input for underground belts to connect)
- [x] Keep `ubi_dir` as `belt_dir_define` (input faces the belt flow direction)
- [x] Manual test: place 3x3 electric mining drills with belt direction south - UBO should face north, UBI should face south, and items should transport correctly through the underground belt pair

### Task 2: Fix beacon placement to fill full column/row

**Files:**
- Modify: `scripts/beacon_placer.lua`

- [x] In the greedy placement loop, change the scoring logic: instead of scoring only drills that haven't hit max_beacons_per_drill, always score a candidate as 1 (valid position) so that all non-colliding positions get filled
- [x] The max_beacons_per_drill limit should still be respected as a preference hint, but should not prevent placing beacons in empty physical space - once all drills have enough beacons, continue placing remaining valid candidates that don't collide
- [x] Alternative simpler approach: after the greedy scored loop finishes, do a second pass over remaining valid candidates and place any that don't collide with existing placements (ignoring drill beacon counts)
- [x] Manual test: place 3x3 drills with beacons - beacons should fill the entire column/row length alongside the drills with no gaps

### Task 3: Restrict poles to 1x1 only and verify pole position near UBI

**Files:**
- Modify: `scripts/gui.lua`

- [x] In `_get_electric_pole_types`, filter out poles where width > 1 or height > 1 (remove substations and big electric poles from the selector)
- [x] Manual test: open the GUI and verify only 1x1 poles appear (small electric pole, medium electric pole)
- [x] Manual test: place drills with poles and underground belts - verify poles are correctly placed in the pole slot row (next to where UBI is placed), not overlapping belts

### Task 4: Final verification

- [ ] Manual test: place 3x3 drills with all three fixes active (correct UBO direction, full beacon columns, 1x1 poles only)
- [ ] Manual test: test with all 4 belt directions (N/S/E/W) to verify UBO rotation works in all orientations
- [ ] Manual test: verify no collisions between poles, belts, and beacons
