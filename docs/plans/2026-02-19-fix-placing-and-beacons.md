Fix Ghost Force-Placement and Beacon Between-Column Placement

## Overview

Two fixes:

1. Change ghost placement to unconditionally place ghosts after demolishing
   conflicts (true "super-force" like Ctrl+Shift+Click), and fix ore filtering
   so drills don't mine wrong ore
2. Fix beacon placement so beacons appear between drill pair columns, not
   just on outer edges, in both productivity and efficient modes

## Context

• Files involved: scripts/ghost_util.lua , scripts/beacon_placer.lua ,
scripts/calculator.lua , scripts/placer.lua
• Related existing plan: docs/plans/2026-02-19-fix-modes-beacons-poles-
ghosts.md (tasks marked complete but issues persist)
• No automated test framework; manual testing in Factorio

## Development Approach

• Testing approach: Manual testing in Factorio
• Complete each task fully before moving to the next

## Implementation Steps

### Task 1: Force-place ghosts unconditionally (super-force placement)

Files:

• Modify: scripts/ghost_util.lua

The current place_ghost function checks can_place_entity twice (before
and after demolishing conflicts) and skips placement if both checks fail.
The fix: always demolish conflicts first, then always call create_entity
to place the ghost unconditionally, regardless of what can_place_entity
returns. This matches Factorio's Ctrl+Shift+Click behavior where placement
is forced.

[x] In ghost_util.place_ghost : always call demolish_conflicts first (not
conditionally)
[x] After demolishing, always call surface.create_entity to place the
ghost, removing the can_place_entity gate entirely
[x] Still return nil, false only if create_entity itself returns nil
(engine-level failure)
[x] Keep the demolish logic (decon non-resource, non-character, non-ghost
entities) as-is

### Task 2: Fix ore filtering - ensure drills don't mine wrong ore

Files:

• Modify: scripts/calculator.lua

The has_foreign_ore_overlap function checks a square region of
max(ceil(body_w/2), floor(radius)) extent. But the actual mining area in
Factorio extends floor(radius) tiles from the drill center on each axis.
For drills where ceil(body_w/2) > floor(radius) , the check region is
larger than the mining area (checking body footprint tiles that aren't
mined). For drills where the body is smaller, the mining area extends beyond
the body, and the current max() approach should cover it. The real issue
may be that has_resources_in_mining_area uses floor(radius) while
has_foreign_ore_overlap uses a different extent - they should use the same
mining area definition.

[x] Align has_foreign_ore_overlap to check exactly the same area as
has_resources_in_mining_area (both should check floor(radius) extent from
floor(cx), floor(cy) )
[x] Remove the body_w/body_h parameters from has_foreign_ore_overlap since
the mining area (not body footprint) is what determines which ores get mined
[x] Update call sites of has_foreign_ore_overlap to match new signature

### Task 3: Widen pair stride to make room for beacons between drill pairs

Files:

• Modify: scripts/calculator.lua
• Modify: scripts/placer.lua (pass beacon info to calculator)

Root cause: In productivity mode, pair_stride = pair_width + 0 + pole_gap,
meaning adjacent drill pairs are packed with zero gap between them. For a
3x3 drill (electric mining drill): pair_stride = 3+1+3 = 7, so the
right_outer edge of pair i touches the left_outer edge of pair i+1
exactly. A 3x3 beacon centered at that boundary collides with drills on
both sides and gets filtered out by beacon_collides. Beacons only appear
on the outer edges where there is open space.

The fix: when beacons are selected in the GUI, increase pair_stride by
the beacon width so there is room for a beacon column between each pair.
The beacon_placer generate_candidates midpoint calculation already
correctly finds the center of the gap - it just needs an actual gap to
exist.

[x] Add a beacon_width parameter to calculator.calculate_positions
(default 0 when no beacons selected)
[x] In placer.lua, look up beacon prototype width when beacon is selected
and pass it to calculate_positions
[x] In calculate_positions, add beacon_width to pair_stride so that
adjacent pairs have enough space: pair_stride = pair_width +
(spacing_across - body_w) + pole_gap + beacon_width
[x] Test with productivity mode + beacons: verify beacon columns appear
between pairs (not just outer edges)
[x] Test with productivity mode without beacons: verify drill layout is
unchanged (beacon_width = 0)
[x] Test with efficient mode + beacons: verify beacons still work
(efficient mode already has large gaps so this should be unaffected)

### Task 4: Verify all fixes work together

[x] Manual test: place drills over an existing base with entities - ghosts
should appear everywhere, conflicting entities marked for decon
[x] Manual test: select a specific ore type adjacent to a different ore -
verify no drills are placed where they'd mine the wrong ore
[x] Manual test: select a large ore patch that generates 2+ drill pairs -
verify beacon columns appear between pairs (not just outer edges)
[x] Manual test: test both productivity and efficient modes with beacons
[x] Verify mod loads without errors
