# Fix Placement Modes, Beacon Layout, 2x2 Pole Gap, and Ghost Collision Handling

## Overview

Four fixes to the miner planner mod:
  1. Remove the "loose" placement mode entirely, keeping only "productivity" and "efficient"
  2. Change beacon placement from outer-edge-only to interleaved between drill columns (sharing beacons between adjacent pairs)
  3. For 2x2 drills, add a 1-tile gap between drill columns for pole placement, and also place poles on the outer edges of drills
  4. Fix ghost placement to order deconstruction of conflicting entities at each placement position, rather than skipping positions where entities exist

## Context

- Files involved: `scripts/calculator.lua`, `scripts/beacon_placer.lua`, `scripts/pole_placer.lua`, `scripts/belt_placer.lua`, `scripts/placer.lua`, `scripts/gui.lua`, `settings.lua`, `locale/en/locale.cfg`, `control.lua`
- No test framework exists in this project

## Development Approach

- **Testing approach**: Manual testing in Factorio (no automated test framework)
- Complete each task fully before moving to the next

## Implementation Steps

### Task 1: Remove "loose" placement mode

**Files:**
- Modify: `scripts/calculator.lua` (remove "loose" branch in `get_spacing`)
- Modify: `scripts/gui.lua` (remove "loose" from `PLACEMENT_MODES`, update default logic)
- Modify: `settings.lua` (remove "loose" from `allowed_values`, change default to "efficient")
- Modify: `locale/en/locale.cfg` (remove loose mode strings)
- Modify: `control.lua` (migrate saved "loose" settings to "efficient")

- [x] Remove the "loose" `elseif` branch from `calculator.get_spacing` (lines 21-26)
- [x] Change `PLACEMENT_MODES` in `gui.lua` from `{"productivity", "loose", "efficient"}` to `{"productivity", "efficient"}`
- [x] Update `gui.create` to migrate legacy "loose" to "efficient" instead of keeping it (line 32)
- [x] Update `gui.handle_radio_change` to iterate over the new 2-mode list
- [x] Update `settings.lua`: remove "loose" from `allowed_values`, change `default_value` to "efficient"
- [x] Remove locale strings: `gui-mode-loose`, `gui-mode-loose-tooltip`, `mineore-default-mode-loose`
- [x] In `control.lua` `on_configuration_changed`: migrate any saved "loose" settings to "efficient"

### Task 2: Interleaved beacon placement between drill columns

**Files:**
- Modify: `scripts/beacon_placer.lua` (rewrite `generate_candidates` to place beacons between drill columns/rows, sharing beacons across adjacent pairs)

Current layout:
```
[Beacon][Drill][belt][Drill][Beacon]  [Beacon][Drill][belt][Drill][Beacon]
```

New layout (beacons shared between adjacent pairs):
```
[Beacon][Drill][belt][Drill][Beacon][Drill][belt][Drill][Beacon]
```

The key insight: beacons between two adjacent drill pairs affect drills on both sides via their supply area. So instead of 4 beacons per pair (2 left + 2 right), adjacent pairs share their inner beacon columns, using 3 beacon columns for 2 pairs instead of 4.

- [x] Rewrite `generate_candidates` to compute beacon column/row positions between drill pairs rather than on outer edges only
- [x] For NS orientation: compute beacon x-positions as the midpoints between adjacent drill pair outer edges, plus the two outermost edges
- [x] For EW orientation: same logic but for y-positions between adjacent row pairs
- [x] The fill logic (stepping by beacon_height/width along each column/row) remains the same
- [x] The greedy coverage algorithm and fill pass remain unchanged - they already handle supply_area_distance correctly
- [x] Update the comment header in `beacon_placer.lua` to reflect the new layout

### Task 3: 2x2 drill pole gap - add 1-tile gap between drill columns for poles, plus outer edge poles

**Files:**
- Modify: `scripts/calculator.lua` (adjust pair stride for 2x2 drills to include pole gap)
- Modify: `scripts/pole_placer.lua` (for 2x2 drills, place poles in the inter-column gaps AND on the outer edges of the drill array)
- Modify: `scripts/belt_placer.lua` (for 2x2 drills, potentially adjust belt extent if poles are no longer on the belt line)

For 2x2 drills, the current layout is:
```
[Drill][belt][Drill]  [Drill][belt][Drill]
         ^poles here
```

New layout (poles in gaps between pairs AND on outer edges):
```
[pole][Drill][belt][Drill][pole gap][Drill][belt][Drill][pole]
  ^                          ^                             ^
  outer edge pole      gap pole                   outer edge pole
```

- [x] In `calculator.lua`, modify the pair stride calculation: for 2x2 drills (body_w <= 2 or body_h <= 2), add 1 extra tile between pairs for the pole gap
- [x] Add a `pole_gap_positions` field to the belt_line metadata that stores the x (NS) or y (EW) positions of the pole gaps between pairs
- [x] In `pole_placer.lua`, when drill is 2x2: place poles in the pole gap columns/rows between pairs
- [x] In `pole_placer.lua`, when drill is 2x2: also place poles along the outer edges (leftmost and rightmost for NS, topmost and bottommost for EW) of the drill array
- [x] For 3x3+ drills, pole placement remains unchanged (poles go on the belt gap center)

### Task 4: Fix ghost placement to demolish conflicting entities

**Files:**
- Modify: `scripts/placer.lua` (change placement logic to demolish conflicting entities instead of skipping)
- Modify: `scripts/belt_placer.lua` (same change for belt ghost placement)
- Modify: `scripts/pole_placer.lua` (same change for pole ghost placement)
- Modify: `scripts/beacon_placer.lua` (same change for beacon ghost placement)

Currently, each placer checks `surface.can_place_entity` with `ghost_place` build check, and if it fails, the position is skipped. The fix should instead:

  1. Find any existing entities at the target position that would block placement
  2. Order those entities for deconstruction
  3. Then place the ghost (which should succeed since ghosts ignore deconstructed entities, or re-check after marking)

- [ ] Create a shared helper function (in `placer.lua` or a new utility) that: given a position and entity prototype, finds conflicting entities using `surface.find_entities_filtered` in the entity's bounding box, orders them for deconstruction, then places the ghost
- [ ] Update drill placement in `placer.lua` to use this helper instead of skip-on-fail
- [ ] Update `belt_placer._place_ghost` and `belt_placer._place_underground_ghost` to demolish conflicts before placement
- [ ] Update `pole_placer._place_ghost` to demolish conflicts before placement
- [ ] Update `beacon_placer.try_place_beacon` to demolish conflicts before placement
- [ ] Handle the character entity specially: the character cannot be deconstructed, so if the character is blocking a position, mark for deconstruction everything else in that tile and still place the ghost (the ghost_place check ignores characters for ghost placement in Factorio 2.0)
- [ ] Remove the initial broad `demolish_obstacles` function since per-position demolition replaces it, OR keep it for clearing trees/rocks in the broader area and add per-position demolition for the actual entity footprints

### Task 5: Verify all changes work together

- [ ] Manual test: select an ore patch and verify only "productivity" and "efficient" modes appear in GUI
- [ ] Manual test: verify beacons are placed between drill columns (shared between pairs) not just on outer edges
- [ ] Manual test: verify 2x2 drills have a pole gap between pairs with poles placed there AND poles on outer edges
- [ ] Manual test: verify ghosts are placed even when existing entities occupy the positions (entities get marked for deconstruction)
- [ ] Verify the mod loads without errors (check Factorio log)

### Task 6: Update documentation

- [ ] Update CLAUDE.md if internal patterns changed
- [ ] Move this plan to `docs/plans/completed/`
