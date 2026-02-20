# Fix Default Mode, Underground Belt Direction, and Drill Filtering Issues

## Overview

Fix three bugs: (1) default mode showing "efficient" instead of "productivity" due to stale saved settings, (2) underground belt pairing broken due to incorrect placement pattern - skip first UBO in belt line since it has no preceding UBI to connect to, and (3) investigate why only diesel drills appear for liquid-requiring ores when electric-mining-drill should also appear.

## Context

- Files involved: scripts/gui.lua, scripts/belt_placer.lua, scripts/resource_scanner.lua
- Related patterns: Settings persistence, ghost entity placement with belt_to_ground_type, technology-based filtering
- Dependencies: None
- Research findings on underground belt pairing:
  - Underground belts pair when an "input" (UBI) connects to an "output" (UBO) within max distance
  - Both should face the same direction for automatic Factorio pairing
  - Placement order matters: in Factorio gameplay, players place input first, then output
  - Current code places output first (UBO), then input (UBI) for each drill position
  - User insight: The FIRST UBO in the sequence has no preceding UBI to connect to, so it shouldn't be placed
  - Pattern should be: First drill gets only UBI, subsequent drills get UBO (connects to previous UBI) then UBI (starts new section)

## Root Cause Analysis

ISSUE 1 - Default Mode Bug:
The settings.lua file correctly has default_value = "productivity". However, when the default was changed from "efficient" to "productivity", existing user save files retained the old "efficient" value. The code at gui.lua:48 only sets the default when settings.placement_mode is nil, so existing saves with "efficient" never get updated to the new default.

ISSUE 2 - Underground Belt Pairing:
Two problems identified:

1. Direction: Current code sets UBO direction to opposite_direction(belt_dir_define), but both UBI and UBO should face the same direction
2. Placement pattern: Code places UBO then UBI for every drill position. However, the FIRST drill in the sequence shouldn't have a UBO because there's no preceding UBI for it to connect to. The first UBO is orphaned and causes connection issues.

Correct pattern for south-flowing belt:

- First drill position: Place only UBI (entrance to underground section)
- Subsequent drill positions: Place UBO (exit from previous section), then UBI (entrance to next section)

ISSUE 3 - Drill Filtering:
For liquid-requiring ores, only diesel drill appears in GUI while electric-mining-drill should also show. The code at gui.lua:378-387 filters to drills with has_fluid_input=true. The resource_scanner.lua:108 sets has_fluid_input based on fluidbox_prototypes. Need to verify if electric-mining-drill has fluid input capability detected correctly, or if this is mod-specific behavior.

## Development Approach

- Testing approach: Regular (code first, then manual tests)
- Complete each task fully before moving to the next
- CRITICAL: every task MUST include new/updated manual test documentation
- CRITICAL: all tests must pass before starting next task

## Implementation Steps

### Task 1: Fix default mode to properly migrate from old "efficient" default

**Files:**

- Modify: scripts/gui.lua

- [x] In gui.create(), after loading settings (line 45), add migration check: if placement_mode is "efficient" and user hasn't explicitly chosen it, reset to mod default
- [x] The migration should detect if the "efficient" value is from the old default vs user choice (treat all "efficient" values as stale for this migration)
- [x] Remove or preserve debug print statements based on whether debugging is still needed
- [x] Test by loading save with "efficient" setting and verify it migrates to "productivity"
- [x] Update docs/tests/productive-mode-default-tests.md with validation results

### Task 2: Fix underground belt direction and placement pattern

**Files:**

- Modify: scripts/belt_placer.lua

- [x] In \_place_underground_belts(), change UBO direction from opposite_direction(belt_dir_define) to belt_dir_define (same as UBI)
- [x] Modify placement logic to skip placing UBO for the FIRST drill position in drill_positions array
- [x] For NS orientation: iterate through drill_positions, skip UBO placement for index 1, place both UBO and UBI for subsequent indices
- [x] For EW orientation: same pattern - skip UBO for first drill, place both for subsequent drills
- [x] Update all comments to explain: (a) both UBI and UBO face same direction, (b) first drill gets only UBI, subsequent drills get UBO then UBI
- [x] Keep opposite_direction() function as it may be useful for future features
- [x] Test underground belt placement for all four directions (north, south, east, west) and verify belts auto-connect without manual R rotation
- [x] Update docs/tests/underground-belt-direction-tests.md with validation results
- [x] Update CLAUDE.md Underground Belt Direction Pattern section with corrected explanation

### Task 3: Investigate and fix drill filtering for liquid ores

**Files:**

- Modify: scripts/gui.lua, potentially scripts/resource_scanner.lua

- [ ] Add debug logging to print all compatible drills and their has_fluid_input status when scanning liquid-requiring ores
- [ ] Test with uranium ore to see which drills are detected and why electric-mining-drill is missing
- [ ] If electric-mining-drill has has_fluid_input=false, investigate why (check if fluidbox detection in resource_scanner.lua:86-97 works correctly)
- [ ] Fix the root cause (either fluidbox detection logic or filtering logic)
- [ ] Test with both normal ore (should show all drills) and uranium ore (should show electric-mining-drill and other fluid-capable drills, excluding burner)
- [ ] Create docs/tests/drill-filtering-for-liquid-ores-tests.md with validation steps and findings

### Task 4: Update documentation

- [ ] Update CLAUDE.md Underground Belt Direction Pattern to reflect the fix (both UBI and UBO face same direction, first drill skips UBO placement)
- [ ] Update CLAUDE.md with any findings about drill filtering for liquid ores
- [ ] Remove debug print statements from gui.lua if they were temporary
- [ ] Move this plan to docs/plans/completed/
